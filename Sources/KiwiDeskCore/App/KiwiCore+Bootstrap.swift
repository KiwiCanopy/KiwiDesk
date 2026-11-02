import AppKit
import Foundation

extension KiwiCore {
    /// Wires core subsystems, event callbacks, and service
    /// integrations during initialization (#415 architect follow-up).
    func bootstrapCoreServices() {
        crash.captureState = { [weak self] in
            self?.sessionSnapshot()
        }
        crash.captureInPlaceState = { [weak self] in
            self?.sessionSnapshot(inPlace: true)
        }
        crash.stopCarry = { [weak self] snapshot in
            self?.state.markingStopFloats(snapshot) ?? snapshot
        }
        crash.onAutosaved = { [weak self] in
            if let self { crash.restoreKeys.autosave(self) }
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
        eventLoop.onLog = log
        keys.onLog = log
        keys.onLayerChange = { [weak self] from, to in
            self?.emitLayerChange(from: from, to: to)
        }
        keys.onBareHyper = { [weak self] in self?.cueBareHyper() }
        keys.onHyperShortcutsChange = { [weak self] in
            self?.onAppWideChange()
        }
        keys.onSideTapStatusChange = { [weak self] in
            self?.onAppWideChange()
        }
        exec.onLog = log
        profiles.onLog = log
        profiles.onActiveChange = { [weak self] in
            self?.liveProfileChanged()
        }
        // A pending binding gains its id at the write that makes its
        // name resolvable, whichever door wrote (#2324).
        profiles.onProfileWritten = { [weak self] in
            self?.promotePendingBindings()
        }
        borders.onLog = log
        socket.onLog = log
        bus.onLog = log
        sleepWake.onLog = log
        // Both force-settle nets report through this one (#611)
        // — an unobservable rescue is how a loud failure becomes
        // a quiet one.
        tiler.animation.onLog = log
        strandDetector.onLog = log
        mouse.scroll.onLog = log
        tiler.motionGate.onLog = log
        vision.appearanceSwitch = .live(onLog: log)
        wireScrollPan()
        wireScrollSpaceStep()
        // QA lever (#596), read once: `KIWIDESK_NO_WS_TRACKING`
        // pins every overlay to the AX-fallback path.
        windowServer.onLog = log
        windowServer.configureFromEnvironment()
        windowServer.atTurnEnd = MainRunLoopTurnEnd.schedule
        connectWindowServerConsumers()
        wireDrag()
        wireOwnKeyWindowRefresh()
        wireHoldGlide()
        wireMotionCause()
        wireSpaceBarLayerRefresh()
        appBars.onSelect = { [weak self] id in
            self?.withUserMotion {
                self?.selectFromAppBar(id)
            }
        }
        spaceBars.onSelectSpace = { [weak self] id in
            self?.withUserMotion {
                self?.fromSpaceBar {
                    _ = self?.focusSpace([.string(id.raw)])
                }
            }
        }
        wireSpaceBarGlyphs()
        wireBarMenus()
        wireBarPeek()
        wireOverflowMarks()
        wirePocketPlate()
        appFont.onLoad = { [weak self] in
            self?.updateBars()
        }
        shelves.reveal.onChange = { [weak self] in self?.updateBars() }
        shelves.reveal.holds = { [weak self] key in
            self?.shelves.surfaceHolds(key) == true
        }
        shelves.reveal.windowMoving = { [weak self] in
            self?.windowMoveInFlight == true
        }
        shelves.handles.onPress = { [weak self] key in
            self?.toggleBarReveal(key)
        }
        shelves.onMinimum = { [weak self] percent, committed in
            self?.withUserMotion {
                self?.dragShelfMinimum(percent, committed: committed)
            }
        }
        appBars.onMove = { [weak self] space, from, to in
            self?.withUserMotion {
                self?.moveBarItem(space: space, from: from, to: to)
            }
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
            // The #677 answer probe: a refused size answers
            // with SILENCE (no event), so a probing window's
            // settle schedules a direct read-back.
            self?.scheduleSizeBoundProbe(id)
        }
        // A state change's held ring waits for its spring to end,
        // settled or cancelled (#2676).
        let animationEnded = tiler.animation.onAnimationEnd
        tiler.animation.onAnimationEnd = { [weak self] id in
            animationEnded(id)
            self?.borders.stateChangeSettled(id)
        }
        // An instant layout write never settles (#2187).
        tiler.onInstantLayoutAsk = { [weak self] id in
            self?.scheduleSizeBoundProbe(id)
        }
        tiler.onFrameApplied = { [weak self] id, frame in
            // The #677 pin: while this animation re-asks a size
            // the app has refused, the truthful render is the
            // commanded origin at the learned answer — computed
            // once here so ring and mark correct together.
            let pin = self?.tiler.animationSizePin(for: id)
            self?.borders.follow(
                id,
                windowFrame: frame,
                source: .animationTick,
                pin: pin
            )
            self?.followMarks(
                id,
                windowFrame: frame,
                source: .animationTick,
                pin: pin
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
        overflowMarks.isAnimating = animationDriven
        windowServer.isAnimating = animationDriven
        // The instant twin of the tick's leading truth (#881):
        // a just-commanded `applyInstant` target leads the
        // echo-fed state frame in the steady-state syncs, so
        // the ring moves at monocle park's instant focus
        // switch instead of a whole echo behind it. ONE
        // closure for both managers, like the predicate above.
        let commandedInstant: @MainActor (WindowID) -> CGRect? =
            { [weak self] id in
                self?.tiler.recentInstantTarget(id)
            }
        borders.commandedFrame = commandedInstant
        stickyMarks.commandedFrame = commandedInstant
        overflowMarks.commandedFrame = commandedInstant
        // Both marks move through the ring's one panel move, so a
        // test core's pin reaches them too (#2531).
        let movePanel: PanelPlacement.Move = {
            [weak self] window, origin in
            MainActor.assumeIsolated {
                self?.borders.movePanel(window, origin) ?? false
            }
        }
        stickyMarks.movePanel = movePanel
        overflowMarks.movePanel = movePanel

        socket.handler = { [weak self] request in
            self?.answer(request) ?? .fail("core unavailable")
        }
        socket.bus = bus
        tiler.elementProvider = { [weak self] id in
            self?.eventLoop.element(for: id)
        }
        // One screen identity for the engine and the bars (#1948).
        tiler.screenFingerprint = { [weak self] screen in
            screen.kiwiDisplayID.flatMap {
                self?.screenFingerprint(of: $0)
            }
        }
        // A resting pocket's edge reserves its strip (#2784).
        tiler.pocketAtRest = { [weak self] in
            self?.pocketHoldsSeveral ?? false
        }
        // The drawn stack side reads the one flip door (#2771).
        tiler.stackFlip = { [weak self] space in
            self?.stackFlip(of: space)
        }
        // The loop owns whether an app's EUI is on at rest; the
        // applier's holds only borrow it (#1508).
        tiler.applier.enhancedUIAtRest = { [weak self] pid in
            self?.eventLoop.enhancedUIBaselines[pid] != nil
        }
        eventLoop.onEnhancedUIRetired = { [weak self] pid, on in
            self?.tiler.applier.retireApp(pid, leftOn: on)
        }
        eventLoop.onEvent = { [weak self] event in
            self?.handle(event)
        }
        eventLoop.foldsSwitchResync = { [weak self] body in
            guard let self else { return body() }
            self.foldingSwitchResync(body)
        }
        eventLoop.switchReads.onApplied = { [weak self] in
            guard let self, self.eventLoop.switchReads.barsOwed
            else { return }
            self.repaintBarsAndFloatNet(animated: false)
        }
        eventLoop.onIgnoredPanelFocus = {
            [weak self] pid, bundleID in
            self?.armIgnoredPanel(pid)
            self?.armAccessibilityReturn(bundleID: bundleID)
        }
        // A command, so its report arrives intended (#1161).
        eventLoop.onUnhideFocus = { [weak self] id in
            self?.focusWindow(id, warp: false)
        }
        eventLoop.onAppActivated = { [weak self] activation in
            self?.noteAppActivation(activation)
            self?.endRaiseFlight()
        }
        eventLoop.onTransientDrop = { [weak self] in
            self?.scheduleTransientRetrack()
        }
        eventLoop.displayWatch.readDrawnMenuBars =
            DisplayWatch.liveMenuBars
        eventLoop.displayWatch.onMenuBarPrefChange = { [weak self] in
            self?.scheduleMenuBarRemeasure()
        }
        eventLoop.onRemovalDistrust = { [weak self] in
            self?.scheduleRemovalRecheck()
        }
        // The #2002 episode opening, on the core's one wall clock.
        eventLoop.wallClock = { [weak self] in
            self?.wallClock() ?? .distantPast
        }
        // Both arrival debts age on it too (#2341).
        followFocus.clock = { [weak self] in
            self?.wallClock() ?? .distantPast
        }
        desktopMemory.returnFocus.clock = { [weak self] in
            self?.wallClock() ?? .distantPast
        }
        eventLoop.onRemovalEpisodesEnded = { [weak self] ids in
            self?.retireDelayedClose(touching: ids, why: "re-listed")
        }
        eventLoop.carriedWindows = { [weak self] in
            self?.stickyReachInFlight() ?? []
        }
        eventLoop.fullscreenSpaceHosts = { [weak self] id in
            self?.windowIsOnFullscreenSpace(id) ?? false
        }
        eventLoop.reachAwaitsCarry = { [weak self] id in
            self?.stickyReachAwaitsCarry(id) ?? false
        }
        eventLoop.lockedRemovals.isLocked = {
            SessionPresence.live().screenLocked == true
        }
        sleepWake.captureState = { [weak self] in
            self?.sessionSnapshot()
        }
        // The wake leg pays the adopted focus for real (#1130);
        // the crash leg above keeps the bare replay.
        sleepWake.restoreState = { [weak self] snapshot in
            self?.restoreAndSettleAfterWake(snapshot)
        }
        sleepWake.onRest = { [weak self] in
            self?.dropRestoreDebt()
        }
        sleepWake.displayFingerprints = { [weak self] in
            self?.liveFingerprints ?? []
        }
        sleepWake.sessionPresence = { .live() }
        sleepWake.onReturn = { [weak self] in
            self?.eventLoop.sessionDidReturn()
        }
    }
}
