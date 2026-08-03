import AppKit
import Foundation

/// Start/stop lifecycle: config load, event loop, session
/// restore, and the delayed startup sweep.
extension KiwiCore {
    /// Loads the config and starts window management.
    ///
    /// Phases are signposted and summarized through `onLog`
    /// (#672): boot cost lives almost entirely in the AX scans
    /// under `loadConfig` / `eventLoop.start()`, and the field
    /// evidence for a hung app is a duration, so every boot
    /// leaves one on record.
    public func start() {
        let signposter = BootSignpost.signposter
        let boot = signposter.beginInterval("boot")
        let bootBegin = ContinuousClock.now
        // Arm the focused-command foreground guard (#292): from now
        // on, an implicit-focused command fails closed unless the OS
        // frontmost app is KiwiDesk's focused managed window. Left
        // nil until here so unit tests are unaffected.
        frontmostPIDProvider = {
            NSWorkspace.shared.frontmostApplication?
                .processIdentifier
        }
        // Arm the raise-echo revert's click-provenance check
        // (#687): the press stamp below resolves which window
        // each click reached. Left nil until here so unit
        // tests never read the host's real windows.
        // `ClickProvenanceWiringTests` pins this wire and the
        // stamp's resolution call — the fix's whole delivery
        // path, which no behavior test can red on (they all
        // inject).
        stackingOrderProvider = {
            AXHelper.onScreenStackingOrder()
        }
        // Yields key focus to the desktop when a move empties the
        // focused display's space (#446) — Finder owns the desktop,
        // gated so it never teleports the user to another Space.
        desktopFocusYield = { [weak self] in
            self?.yieldFocusToDesktop()
        }
        // The warp's machine tail (#186): target geometry is
        // pure (`MouseWarp.target`), the cursor read and the
        // pointer move are not. Left nil until here so unit
        // tests never move the developer's pointer.
        pointerWarp = { frame in
            guard
                let target = MouseWarp.target(
                    frame: frame,
                    cursor: CGEvent(source: nil)?.location
                )
            else { return }
            CGWarpMouseCursorPosition(target)
            // A programmatic warp decouples the hardware mouse
            // for the local-events suppression interval
            // (~250 ms) — a dead mouse right when "the next
            // click lands where the keyboard works" is the
            // whole point. Re-associate immediately so the
            // pointer is live.
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        // A bare left click on another monitor's empty desktop
        // moves the focused display (#446). The press also
        // stamps the click discriminator for the cross-display
        // sibling distrust (#496) — in AX coordinates, the
        // space window frames live in.
        mouse.onLeftMouseDown = { [weak self] point in
            let axPoint = GeometryUtils.axPoint(point)
            // Resolve which window the press reached NOW, not
            // when a raise echo asks (#687): press time is when
            // the fact exists — `clickReachedWindow` carries
            // the argument.
            self?.lastLeftClick = (
                Date(),
                axPoint,
                self?.clickReachedWindow(at: axPoint)
            )
            self?.followDisplayUnderClick(at: point)
        }
        lastNativeSpace = NativeSpaces.activeSpaceNumber()
        // Cheap and off-main; kicked here so the first glyph
        // bar never renders an image-fallback frame.
        appFont.preload()
        borders.start()
        // The mark rides the ring's WindowServer bounds stream —
        // AX move echoes alone lag visibly during drags. The
        // reposition path is unguarded (WS bounds are the truth);
        // the reorder tee re-asserts stacking on a raise that fires
        // no AX focus event (a re-click on the focused window); and
        // the tracking predicate lets the mark's AX-echo `follow`
        // stand down while the WS stream owns the frame.
        borders.onFrameReconciled = { [weak self] id, frame in
            self?.stickyMarks
                .reposition(id, windowFrame: frame)
        }
        borders.onWindowReordered = { [weak self] id in
            self?.stickyMarks.reassert(id)
        }
        stickyMarks.isWindowServerTracked = { [weak self] id in
            self?.borders.markUsesWindowServerTracking(id) ?? false
        }
        let config = signposter.beginInterval("loadConfig")
        loadConfig()
        signposter.endInterval("loadConfig", config)
        let configDone = ContinuousClock.now
        sleepWake.start()
        // One retile for the whole scan instead of one per
        // discovered window (#672): windows fold into state as
        // the events arrive, geometry lands once below. The
        // per-event #193 pile restore was suppressed with the
        // retiles, so re-arm it once here — it self-gates on
        // track + actual overflow.
        defersEventRetiles = true
        eventLoop.start()
        defersEventRetiles = false
        retile()
        scheduleTrackZOrderRestoreIfOverflowing()
        let scanDone = ContinuousClock.now
        mouse.start()
        // The event loop discovered windows in AX order; put
        // back the arrangement of the previous session.
        let restoreSpan =
            signposter.beginInterval("sessionRestore")
        if let session = crash.consumeSession() {
            restore(session)
            activateSpaceOfFocusedWindow()
            seedStartupFocus()
            // Same contract as every other space switch:
            // force past the tolerance check, respect the
            // space-switch animation setting (coordinated
            // out+in, #207), and tell bus subscribers (the
            // bar) where we landed.
            spaceSwitchRetile()
            emitSpaceChange()
            onLog("restored previous session arrangement")
        }
        signposter.endInterval("sessionRestore", restoreSpan)
        crash.start()
        do {
            try socket.start()
        } catch {
            onLog("socket server failed: \(error)")
        }
        scheduleStartupSweep()
        scheduleAdoptionHeal()
        signposter.endInterval("boot", boot)
        let now = ContinuousClock.now
        let configMs =
            bootBegin.duration(to: configDone).wholeMilliseconds
        let scanMs =
            configDone.duration(to: scanDone).wholeMilliseconds
        let tailMs = scanDone.duration(to: now).wholeMilliseconds
        let totalMs =
            bootBegin.duration(to: now).wholeMilliseconds
        onLog(
            "boot: config \(configMs)ms, scan \(scanMs)ms, "
                + "restore+services \(tailMs)ms, "
                + "total \(totalMs)ms"
        )
    }

    /// The startup scan ran against cold AX trees; slow
    /// responders list windows late or mis-report subroles
    /// (see AGENTS.md). One delayed sweep re-tracks what the
    /// scan missed — session restore has remembered their
    /// spaces. If the user has not switched away meanwhile,
    /// the landing choice is re-run: the focused window may
    /// only now be resolvable to its space.
    ///
    /// Internal (not private): the sweep is the promise the
    /// boot prefilter's warmup skip rests on (#662), so
    /// `StartupSweepTests` drives it directly and asserts the
    /// fired task reconciles — `start()` itself is not
    /// test-drivable.
    func scheduleStartupSweep() {
        let landed = state.workspaces.activeSpace
        deferred.schedule(.startupSweep, after: .seconds(1)) {
            [weak self] in
            guard let self, self.eventLoop.isRunning
            else { return }
            let signposter = BootSignpost.signposter
            let sweep = signposter.beginInterval("startupSweep")
            let begin = ContinuousClock.now
            // Same batching as the boot scan: what the sweep
            // discovers lands in one retile, and the #193 pile
            // restore is re-armed once after it (#672).
            self.defersEventRetiles = true
            self.eventLoop.reconcileAll()
            self.defersEventRetiles = false
            self.retile()
            self.scheduleTrackZOrderRestoreIfOverflowing()
            signposter.endInterval("startupSweep", sweep)
            let ms =
                begin.duration(to: .now).wholeMilliseconds
            self.onLog("startup sweep: \(ms)ms")
            if self.state.workspaces.activeSpace == landed {
                self.activateSpaceOfFocusedWindow()
                if self.state.workspaces.activeSpace != landed {
                    self.spaceSwitchRetile()
                    self.emitSpaceChange()
                }
            }
            // Runs even when the user already switched away:
            // a hotkey space switch fires no focus event, so
            // the seed is still the only anchor source (#442).
            self.seedStartupFocus()
        }
    }

    /// The steady-state net under the one-shot sweep above
    /// (#675): every event-driven adoption path can go silent
    /// at once for a fresh-launch app (a failed observer
    /// registration emits nothing, ever), so this re-arms
    /// itself for the whole session. The work it schedules is
    /// gated — `EventLoop.healSweep` reconciles only where the
    /// WindowServer census names an untracked window — and the
    /// stored `adoptionHealInterval` carries the cadence and its
    /// argument beside the value. `stop()`'s
    /// `deferred.cancelAll()` ends the chain; a later `start()`
    /// re-arms it.
    func scheduleAdoptionHeal() {
        deferred.schedule(
            .adoptionHeal,
            after: adoptionHealInterval
        ) { [weak self] in
            guard let self else { return }
            if self.eventLoop.isRunning {
                self.eventLoop.healSweep()
            }
            self.scheduleAdoptionHeal()
        }
    }

    /// One-shot re-track for windows the transient filters
    /// dropped mid-launch (#675); the stored
    /// `transientRetrackDelay` carries the delay and its
    /// argument beside the value. Drains every pid queued since
    /// the fire was armed (`markTransientDrop` arms only from
    /// idle, so a drip of drops cannot push the deadline back).
    func scheduleTransientRetrack() {
        deferred.schedule(
            .transientRetrack,
            after: transientRetrackDelay
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning
            else { return }
            for pid in self.eventLoop.drainPendingRetrack() {
                self.eventLoop.reconcile(
                    pid: pid,
                    app: AppRef(pid: pid)
                )
            }
        }
    }

    public func stop() {
        // Retire focus rings first: the gather below moves windows
        // by direct AX (no animation tee), so a ring left up would
        // sit stranded over the scattered desktop.
        borders.stop()
        stickyMarks.clear()
        // Gather windows onto their owning monitors before
        // any subsystem teardown; AX must still be live here.
        gatherWindows()
        // exec children are fire-and-forget: we do not
        // terminate or wait for them. They are re-parented to
        // launchd and finish naturally after the app exits.
        // Per-command control is available via the optional
        // timeout argument to KiwiDesk.exec(). stop() also runs
        // mid-session on an AX-permission revoke, so cancel any
        // armed timeout watchdogs — they must not SIGTERM a
        // child after teardown (a start() may reuse the launcher).
        exec.cancelWatchdogs()
        deferred.cancelAll()
        mouse.stop()
        eventLoop.stop()
        sleepWake.stop()
        socket.stop()
        crash.shutdownCleanly()
    }
}
