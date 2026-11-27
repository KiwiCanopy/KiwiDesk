import Foundation

/// The session's renumber of the connected setup (#3647 ▸ lane 2b):
/// a Settings Save sets it before the pins are projected, and it
/// stands only for the profile it was made for, on the setup it was
/// made on. One store and one setter, on ProfileManager; profiles.md
/// names who carries it and who clears it.
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
    public var sessionScreenOrder: ScreenOrder? {
        sessionScreenOrder(for: profiles.currentName)
    }

    /// Sets the live profile's numbering of the connected screens for
    /// the session; nil clears it. A Save calls it before its pins
    /// are projected. A screen's split follows its number (#3647 ▸
    /// lane 3), so the placements follow the order at once.
    public func setSessionScreenOrder(_ order: ScreenOrder?) {
        profiles.setSessionScreenOrder(order, for: profiles.currentName)
        syncAreaSplits()
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

    /// A Save adopted `profile` with `carried`, the live renumber read
    /// before it: the renumber follows to it, and ends where the Save
    /// stored it.
    func settleSessionScreenOrder(
        _ carried: ScreenOrder?,
        savedAs profile: Profile
    ) {
        if let carried {
            profiles.setSessionScreenOrder(carried, for: profile.name)
        }
        clearSessionScreenOrder(ifStoredIn: profile)
    }
}
