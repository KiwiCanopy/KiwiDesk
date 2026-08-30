/// Resolves opening layout modes per screen for saved-profile
/// preview cards (#789, #959) — the static shadow of
/// `SpacePlacement`, answering its first two legs (pin, Main
/// role) in the same order; a change to the precedence belongs in
/// `SpacePlacement` first, and here second. Two accepted
/// residues, pinned by `ProfileOpeningModesTests`: a space pinned
/// to the MAIN display lets a blank secondary borrow Main's
/// glyph, and a multi-set profile answers from
/// `monitorSets.first`, which a screen blank there may contradict
/// in another set.
extension Profile {
    /// Opening layout mode for each screen in monitor order
    /// (nil if unassigned).
    public func openingModes() -> [LayoutMode?] {
        let screens = monitorCount
        guard screens > 0 else { return [] }
        guard screens > 1 else {
            return [orderedSpaces.first.flatMap { spaceModes[$0] }]
        }
        guard let set = monitorSets.first else {
            return Array(repeating: nil, count: screens)
        }
        var firsts = set.monitors.prefix(screens).map {
            firstSpace(pinnedTo: $0, in: set)
        }
        if let main = soleUnpinnedScreen(in: firsts),
            let space = firstMainSpace(in: set)
        {
            firsts[main] = space
        }
        return firsts.map { $0.flatMap { spaceModes[$0] } }
    }

    /// Index of sole unpinned screen in set (nil if 0 or >1, #959).
    private func soleUnpinnedScreen(
        in firsts: [SpaceID?]
    ) -> Int? {
        let blank = firsts.indices.filter { firsts[$0] == nil }
        return blank.count == 1 ? blank.first : nil
    }

    /// First ordered space assigned to the Main role WITHOUT a
    /// pin: `SpacePlacement.resolve` gives the pin precedence, so
    /// a space carrying both opens on the pinned screen — painting
    /// the blank one with its mode would name a screen it never
    /// reaches. The GUI writers clear one when they set the other;
    /// a hand-edited profile can carry both.
    private func firstMainSpace(in set: MonitorSet) -> SpaceID? {
        let main = Set(mainSpaces)
        return orderedSpaces.first {
            main.contains($0) && set.spaceMonitorMap[$0] == nil
        }
    }

    /// First ordered space pinned to the fingerprint — the
    /// profile's own order decides "first", never the
    /// dictionary's, which would pick differently between
    /// launches.
    private func firstSpace(
        pinnedTo fingerprint: String,
        in set: MonitorSet
    ) -> SpaceID? {
        orderedSpaces.first {
            set.spaceMonitorMap[$0] == fingerprint
        }
    }
}
