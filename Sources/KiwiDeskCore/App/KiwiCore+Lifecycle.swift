import AppKit
import Foundation

/// Steady-state lifecycle: the delayed startup sweep, the
/// self-rearming adoption heal, the transient re-track, and
/// teardown. Coming up is `KiwiCore+Boot`.
extension KiwiCore {
    /// The startup scan ran against cold AX trees; slow
    /// responders list windows late or mis-report subroles
    /// (see AGENTS.md). One delayed sweep re-tracks what the
    /// scan missed — session restore has remembered their
    /// spaces. If the user has not switched away meanwhile,
    /// the landing choice is re-run: the focused window may
    /// only now be resolvable to its space.
    ///
    /// Chunked and budgeted exactly like the boot scan (#801):
    /// unchunked it measured 5285 ms one second after boot, which
    /// re-broke the menu right after the scan freed it.
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
            guard let self, self.eventLoop.isRunning,
                self.eventLoop.beginSweep()
            else { return }
            // Batched PER CHUNK, not per pass. The batching is
            // #672's (what a bulk pass discovers lands in one
            // retile, not one per window), but the sweep is no
            // longer one synchronous block: holding the deferral
            // across the whole pass leaves a window created
            // seconds after boot untiled while the mark already
            // says ready (code review, 2026-08-12). A chunk is the
            // shortest batch that still collapses the burst.
            self.defersEventRetiles = true
            self.driveChunkedPass(
                onChunk: { [weak self] _ in
                    self?.foldSweepChunk()
                },
                onFinish: { [weak self] in
                    self?.finishStartupSweep(landed: landed)
                }
            )
        }
    }

    /// One chunk's discoveries land as one retile, and the
    /// deferral is re-raised for the next chunk.
    ///
    /// The retile is per chunk; the z-order arm is NOT. A sweep
    /// over a hundred apps would otherwise arm dozens of times
    /// while almost every chunk discovers nothing, and in track
    /// mode each arm drains a verified raise sequence on the
    /// blocking ordered queue — holding the mouse warp for its
    /// whole span, seconds after the mark went bright.
    /// "Harmless, it re-raises the same order" is exactly the
    /// argument state-and-layout.md ▸ "Arm narrowly" rejects, so
    /// the single arm stays in the epilogue (architect review,
    /// 2026-08-12).
    private func foldSweepChunk() {
        defersEventRetiles = false
        retile()
        defersEventRetiles = true
    }

    private func finishStartupSweep(landed: SpaceID?) {
        defersEventRetiles = false
        retile()
        scheduleTrackZOrderRestoreIfOverflowing()
        // The sweep budgets its apps exactly as the scan does, so
        // it owes the same completion (#803).
        drainDeferredBootApps()
        if state.workspaces.activeSpace == landed {
            activateSpaceOfFocusedWindow()
            if state.workspaces.activeSpace != landed {
                spaceSwitchRetile()
                emitSpaceChange()
            }
        }
        // Runs even when the user already switched away: a
        // hotkey space switch fires no focus event, so the seed
        // is still the only anchor source (#442).
        seedStartupFocus()
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
        // A stop of a launch that never finished booting must not
        // write the session file: `shutdownCleanly` captures live
        // state over it, and a launch cut off mid-scan holds a
        // fraction of the desk — written there it would overwrite
        // the arrangement this launch had not restored yet, and
        // the next launch would accept it (its `capturedAt` is
        // after `kern.boottime`). Unreachable while boot was
        // synchronous; a quit or a permission revoke at second 3
        // of a chunked scan reaches it.
        //
        // Keyed on the LATCH, not on `phase`: this stop is about
        // to publish `.idle`, so a second stop — quitting after a
        // mid-boot revoke — would read as "not starting" and
        // write the partial desk the first stop just protected
        // (code review, 2026-08-12).
        if !boot.reachedReady {
            crash.shutdownCleanly(preservingSession: true)
            onLog("stopped before ready; previous session kept")
        } else {
            crash.shutdownCleanly()
        }
        // A stop mid-boot leaves the readiness signal up
        // otherwise: `deferred.cancelAll()` above killed the
        // chunk continuation, so nothing else would ever publish
        // again. A permission revoke is the live case (#802) —
        // paused management is not a boot in progress.
        defersEventRetiles = false
        closeBootInterval()
        boot.publish(.idle)
    }
}
