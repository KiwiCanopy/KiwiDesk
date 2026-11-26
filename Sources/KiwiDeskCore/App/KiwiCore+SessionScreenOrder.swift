import Foundation

/// The session's renumber of the connected setup (#3647 ▸ lane 2):
/// a Settings Save sets it before the pins are projected, and it
/// stands only for the live profile on the setup it was made on.
/// One store, one setter, one clear; profiles.md names who clears.
extension KiwiCore {
    /// The override for the connected screens, nil on another setup.
    var sessionScreenOrder: ScreenOrder? {
        guard let order = profiles.sessionScreenOrder,
            MonitorSet(monitors: order.fingerprints)
                .matches(liveFingerprints)
        else { return nil }
        return order
    }

    /// Sets the live profile's numbering of the connected screens for
    /// the session; nil clears it. A Save calls it before its pins
    /// are projected.
    public func setSessionScreenOrder(_ order: ScreenOrder?) {
        profiles.sessionScreenOrder = order
    }

    /// Ends the override: an explicit load or pick, a composed apply,
    /// the #634 reset, and a Save that wrote it.
    func clearSessionScreenOrder() {
        profiles.sessionScreenOrder = nil
    }

    /// Clears the override once a Save stored `profile` in its order:
    /// a hole is never stored, so it outlives the Save.
    func clearSessionScreenOrder(ifStoredIn profile: Profile) {
        guard let order = sessionScreenOrder, order.unnumbered.isEmpty,
            profile.monitorSets.contains(where: {
                $0.monitors == order.fingerprints
            })
        else { return }
        clearSessionScreenOrder()
    }
}
