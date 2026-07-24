import AppKit
import Foundation

/// Start/stop lifecycle: config load, event loop, session
/// restore, and the delayed startup sweep.
extension KiwiCore {
    /// Loads the config and starts window management.
    public func start() {
        // Arm the focused-command foreground guard (#292): from now
        // on, an implicit-focused command fails closed unless the OS
        // frontmost app is KiwiDesk's focused managed window. Left
        // nil until here so unit tests are unaffected.
        frontmostPIDProvider = {
            NSWorkspace.shared.frontmostApplication?
                .processIdentifier
        }
        // Yields key focus to the desktop when a move empties the
        // focused display's space (#446) — Finder owns the desktop,
        // gated so it never teleports the user to another Space.
        desktopFocusYield = { [weak self] in
            self?.yieldFocusToDesktop()
        }
        // A bare left click on another monitor's empty desktop
        // moves the focused display (#446).
        mouse.onLeftMouseDown = { [weak self] point in
            self?.followDisplayUnderClick(at: point)
        }
        lastNativeSpace = NativeSpaces.activeSpaceNumber()
        // Cheap and off-main; kicked here so the first glyph
        // bar never renders an image-fallback frame.
        appFont.preload()
        borders.start()
        // The chip rides the ring's WindowServer bounds stream —
        // AX move echoes alone lag visibly during drags. The
        // reposition path is unguarded (WS bounds are the truth);
        // the reorder tee re-asserts stacking on a raise that fires
        // no AX focus event (a re-click on the focused window); and
        // the tracking predicate lets the chip's AX-echo `follow`
        // stand down while the WS stream owns the frame.
        borders.onFrameReconciled = { [weak self] id, frame in
            self?.stickyIndicators
                .reposition(id, windowFrame: frame)
        }
        borders.onWindowReordered = { [weak self] id in
            self?.stickyIndicators.reassert(id)
        }
        stickyIndicators.isWindowServerTracked = { [weak self] id in
            self?.borders.chipUsesWindowServerTracking(id) ?? false
        }
        loadConfig()
        sleepWake.start()
        eventLoop.start()
        mouse.start()
        // The event loop discovered windows in AX order; put
        // back the arrangement of the previous session.
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
        crash.start()
        do {
            try socket.start()
        } catch {
            onLog("socket server failed: \(error)")
        }
        scheduleStartupSweep()
    }

    /// The startup scan ran against cold AX trees; slow
    /// responders list windows late or mis-report subroles
    /// (see AGENTS.md). One delayed sweep re-tracks what the
    /// scan missed — session restore has remembered their
    /// spaces. If the user has not switched away meanwhile,
    /// the landing choice is re-run: the focused window may
    /// only now be resolvable to its space.
    private func scheduleStartupSweep() {
        let landed = state.workspaces.activeSpace
        deferred.schedule(.startupSweep, after: .seconds(1)) {
            [weak self] in
            guard let self, self.eventLoop.isRunning
            else { return }
            self.eventLoop.reconcileAll()
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

    public func stop() {
        // Retire focus rings first: the gather below moves windows
        // by direct AX (no animation tee), so a ring left up would
        // sit stranded over the scattered desktop.
        borders.stop()
        stickyIndicators.clear()
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
