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
        crash.onLog = { [weak self] message in
            self?.onLog(message)
        }
        keys.onLog = { [weak self] message in
            self?.onLog(message)
        }
        exec.onLog = { [weak self] message in
            self?.onLog(message)
        }
        profiles.onLog = { [weak self] message in
            self?.onLog(message)
        }
        borders.onLog = { [weak self] message in
            self?.onLog(message)
        }
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
        borders.isAnimating = { [weak self] id in
            self?.tiler.animation.isAnimating(window: id)
                ?? false
        }
        stickyMarks.isAnimating = { [weak self] id in
            self?.tiler.animation.isAnimating(window: id)
                ?? false
        }

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
        bus.onLog = { [weak self] message in
            self?.onLog(message)
        }
    }
}
