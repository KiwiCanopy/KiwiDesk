import Foundation

/// The session's renumber of the connected setup (#3647 ▸ lane 2b):
/// a Settings Save sets it before the pins are projected, and it
/// stands only for the profile it was made for, on the setup it was
/// made on. One store, one setter, one clear; profiles.md names who
/// clears.
extension KiwiCore {
    /// The override `profile` reads on the connected screens; nil for
    /// another profile or another setup.
    func sessionScreenOrder(for profile: String?) -> ScreenOrder? {
        guard let stored = profiles.sessionScreenOrder,
            stored.profile == profile,
            MonitorSet(monitors: stored.order.fingerprints)
                .matches(liveFingerprints)
        else { return nil }
        return stored.order
    }

    /// The live profile's override, nil where it has none.
    var sessionScreenOrder: ScreenOrder? {
        sessionScreenOrder(for: profiles.currentName)
    }

    /// Sets the live profile's numbering of the connected screens for
    /// the session; nil clears it. A Save calls it before its pins
    /// are projected.
    public func setSessionScreenOrder(_ order: ScreenOrder?) {
        profiles.setSessionScreenOrder(order, for: profiles.currentName)
    }

    /// Ends the override: an explicit load or pick, a composed apply,
    /// the #634 reset, and a Save that wrote it.
    func clearSessionScreenOrder() {
        profiles.setSessionScreenOrder(nil, for: nil)
    }

    /// Clears the override once a Save stored `profile` in its order:
    /// a hole is never stored, so it outlives the Save.
    func clearSessionScreenOrder(ifStoredIn profile: Profile) {
        guard let order = sessionScreenOrder(for: profile.name),
            order.unnumbered.isEmpty,
            profile.monitorSets.contains(where: { $0.order == order })
        else { return }
        clearSessionScreenOrder()
    }
}
