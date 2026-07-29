import AppKit
import Foundation

extension KiwiCore {
    /// Wires core subsystems, event callbacks, and service
    /// integrations during initialization (#415 architect follow-up).
    func bootstrapCoreServices() {
        crash.captureState = { [weak self] in
            self?.state.snapshot()
        }
        crash.restoreState = { [weak self] snapshot in
            self?.restore(snapshot)
        }
        // Every diagnostic seam in Core is wired here, together,
        // through one forwarding closure (core-boundaries.md).
        // Together so that a seam missing from the group is
        // missing from a run of near-identical lines rather than
        // from a hundred-line function — that is the half
        // `LogSeamWiringTests` catches. One closure because a
        // copy of the body per seam is a chance per seam to
        // write a subtly different one — this shape prevents
        // that, and `LogSeamProbeTests` detects it (#625) by
        // requiring each seam's line back out of the sink.
        // That probe compares the line exactly, so a seam whose
        // body decorated its line would red even though it
        // routes; keep the shared closure rather than working
        // around it.
        let log: @MainActor (String) -> Void = { [weak self] in
            self?.onLog($0)
        }
        crash.onLog = log
        keys.onLog = log
        exec.onLog = log
        profiles.onLog = log
        borders.onLog = log
        socket.onLog = log
        bus.onLog = log
        // Both force-settle nets report through this one (#611)
        // — an unobservable rescue is how a loud failure becomes
        // a quiet one.
        tiler.animation.onLog = log
        // QA lever (#596), read once: `KIWIDESK_NO_WS_TRACKING`
        // pins the ring and mark to the AX-fallback path.
        borders.configureFromEnvironment()
        wireDrag()
        appBars.onSelect = { [weak self] id in
            self?.focusWindow(id, warp: true)
        }
        spaceBars.onSelectSpace = { [weak self] id in
            _ = self?.focusSpace([.string(id.raw)])
        }
        appFont.onLoad = { [weak self] in
            self?.updateAppBar()
            self?.updateSpaceBar()
        }
        appBars.onMove = { [weak self] space, from, to in
            self?.moveBarItem(space: space, from: from, to: to)
        }
        tiler.animation.onAllAnimationsEnded = { [weak self] in
            self?.animationsDidSettle()
        }
        tiler.animation.reduceMotion = {
            NSWorkspace.shared
                .accessibilityDisplayShouldReduceMotion
        }
        strandDetector.configureFromEnvironment()
        strandDetector.frameReader = { [weak self] id in
            guard let element = self?.eventLoop.element(for: id)
            else { return nil }
            return AXHelper.frame(of: element)
        }
        tiler.animation.onWindowSettled = { [weak self] id, target in
            self?.strandDetector.windowSettled(id, target: target)
        }
        tiler.onFrameApplied = { [weak self] id, frame in
            self?.borders.follow(
                id,
                windowFrame: frame,
                source: .animationTick
            )
            self?.stickyMarks.follow(
                id,
                windowFrame: frame,
                source: .animationTick
            )
        }
        // Mid-animation the commanded tick frame leads the real
        // bounds on slow-AX apps (#594): while this answers
        // true, the AX-echo follows and the WS reconcile stand
        // down so the ring and mark ride the tick, not the lag.
        // ONE closure for both managers, so ring and mark cannot
        // diverge when this predicate is next refined (#596).
        // Distinct from the drag pipeline's broader self-driven
        // check (`KiwiCore+Drag`), which also spans trailing
        // echoes via `didRecentlySetFrame` — narrower on
        // purpose: folding that in would suppress the
        // post-settle echo, the only carrier of ring updates
        // after an instant `setFrame` under AX fallback (#596).
        let animationDriven: @MainActor (WindowID) -> Bool = {
            [weak self] id in
            self?.tiler.animation.isAnimating(window: id)
                ?? false
        }
        borders.isAnimating = animationDriven
        stickyMarks.isAnimating = animationDriven

        socket.handler = { [weak self] command, args in
            self?.execute(command, args: args)
                ?? .fail("core unavailable")
        }
        socket.bus = bus
        tiler.elementProvider = { [weak self] id in
            self?.eventLoop.element(for: id)
        }
        eventLoop.onEvent = { [weak self] event in
            self?.handle(event)
        }
        eventLoop.onIgnoredPanelFocus = { [weak self] pid in
            self?.ignoredPanelActive.insert(pid)
        }
        sleepWake.captureState = { [weak self] in
            self?.state.snapshot()
        }
        sleepWake.restoreState = { [weak self] snapshot in
            self?.restore(snapshot)
        }
    }
}
