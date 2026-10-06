import Foundation

/// WindowServer's window create/destroy as a WAKE-UP for the AX
/// path (#1877): a fresh app's observer may never deliver its
/// first `AXWindowCreated`, leaving the window to the 5 s
/// adoption heal (#1599 measured 0.6–6.3 s). A create pulls that
/// heal forward — its census read, gate, quiet ledger and
/// unwatched-app attach are the ones it always had — and a
/// destroy asks the app still tracking the window. The AX path
/// stays the truth and the heal's own cadence the backstop.
extension KiwiCore {
    /// How long a create waits before the heal it pulls forward,
    /// so the AX path answers first and a burst costs one sweep.
    static let wakeUpGrace: Duration = .milliseconds(300)

    /// Routes WindowServer's changes here; gated with the live
    /// workspace observers, which a lifecycle suite turns off.
    func startWindowServerWakeUp() {
        guard eventLoop.registersWorkspaceObservers else { return }
        let active = SkyLightWindowLifecycle.start { [weak self] in
            self?.windowServerChanged($0, id: $1)
        }
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
        case .created: pullAdoptionHealForward()
        case .destroyed: eventLoop.windowServerDestroyed(id)
        }
    }

    /// Runs the adoption heal after the grace, unless a pulled
    /// heal is already pending — a burst of creates never pushes
    /// it later. The heal re-arms its own cadence when done.
    func pullAdoptionHealForward() {
        guard eventLoop.isRunning,
            !deferred.isScheduled(.adoptionHealWake)
        else { return }
        deferred.schedule(
            .adoptionHealWake,
            after: Self.wakeUpGrace
        ) { [weak self] in
            guard let self else { return }
            self.deferred.cancel(.adoptionHealWake)
            guard self.eventLoop.isRunning else { return }
            self.deferred.cancel(.adoptionHeal)
            self.deferred.track(
                .adoptionHealRead,
                self.eventLoop.requestHealSweep { [weak self] in
                    self?.scheduleAdoptionHeal()
                }
            )
        }
    }
}
