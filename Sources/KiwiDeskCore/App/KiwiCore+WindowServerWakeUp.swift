import Foundation

/// WindowServer's window create/destroy as a WAKE-UP for the AX
/// path (#1877): a fresh app's observer may never deliver its
/// first `AXWindowCreated`, leaving the window to the 5 s
/// adoption heal (#1599 measured 0.6–6.3 s). A create runs one
/// ledger-free wake sweep after a grace (`EventLoop.wakeSweep`);
/// a destroy asks the app still tracking the window. The AX path
/// stays the truth and the heal's own cadence, untouched, the
/// backstop.
extension KiwiCore {
    /// How long a create waits before its wake sweep, so the AX
    /// path answers first and a burst costs one census read.
    static let wakeUpGrace: Duration = .milliseconds(300)

    /// Routes WindowServer's changes here; gated with the live
    /// workspace observers, which a lifecycle suite turns off.
    func startWindowServerWakeUp() {
        guard eventLoop.registersWorkspaceObservers else { return }
        let active = SkyLightWindowLifecycle.start { [weak self] in
            self?.windowServerChanged($0, id: $1)
        }
        windowCreates.isLive = active
        onLog(
            "WindowServer window wake-up "
                + (active ? "active" : "unavailable")
        )
    }

    /// One create or destroy.
    func windowServerChanged(
        _ change: SkyLightWindowLifecycle.Change,
        id: WindowID
    ) {
        switch change {
        case .created:
            // Our own panels (rings, shelf, slide plates) are no
            // app's arrival, and a Space switch creates them.
            guard EventLoop.ownWindow(number: Int(id.raw)) == nil
            else { return }
            windowCreates.noteCreated(id, at: wallClock())
            // Paid off the port's drain, which the border pump
            // waits on: a follow raises and retiles.
            if launchFollow.spawn?.window == id {
                deferred.schedule(.lateSpawnFollow, after: .zero) {
                    [weak self] in self?.payLateSpawnFollow(id)
                }
            }
            pullWakeSweep()
        case .destroyed:
            windowCreates.noteDestroyed(id)
            eventLoop.windowServerDestroyed(id)
            noteAwayDestroyed(id)
        }
    }

    /// Runs one wake sweep after the grace, unless one is already
    /// pending or reading — a burst of creates never pushes it
    /// later, and costs one census read.
    func pullWakeSweep() {
        guard eventLoop.isRunning,
            !deferred.isScheduled(.adoptionHealWake)
        else { return }
        deferred.schedule(
            .adoptionHealWake,
            after: Self.wakeUpGrace
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning else {
                self?.deferred.cancel(.adoptionHealWake)
                return
            }
            self.deferred.track(
                .adoptionHealWake,
                self.eventLoop.requestWakeSweep { [weak self] in
                    self?.deferred.cancel(.adoptionHealWake)
                }
            )
        }
    }
}
