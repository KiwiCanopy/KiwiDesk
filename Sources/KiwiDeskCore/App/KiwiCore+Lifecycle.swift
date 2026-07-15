import AppKit
import Foundation

/// Start/stop lifecycle: config load, event loop, session
/// restore, and the delayed startup sweep.
extension KiwiCore {
    /// Loads the config and starts window management.
    public func start() {
        lastNativeSpace = NativeSpaces.activeSpaceNumber()
        borders.start()
        loadConfig()
        sleepWake.start()
        eventLoop.start()
        mouse.start()
        // The event loop discovered windows in AX order; put
        // back the arrangement of the previous session.
        if let session = crash.consumeSession() {
            restore(session)
            activateSpaceOfFocusedWindow()
            // Same contract as every other space switch:
            // force past the tolerance check, respect the
            // space-switch animation setting, and tell bus
            // subscribers (the bar) where we landed.
            retile(
                animated: tiler.settings.animations.onSpaceChange,
                force: true
            )
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
            guard
                self.state.workspaces.activeSpace == landed
            else { return }
            self.activateSpaceOfFocusedWindow()
            if self.state.workspaces.activeSpace != landed {
                self.retile(
                    animated: self.tiler.settings.animations.onSpaceChange,
                    force: true
                )
                self.emitSpaceChange()
            }
        }
    }

    public func stop() {
        // Retire focus rings first: the gather below moves windows
        // by direct AX (no animation tee), so a ring left up would
        // sit stranded over the scattered desktop.
        borders.stop()
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
