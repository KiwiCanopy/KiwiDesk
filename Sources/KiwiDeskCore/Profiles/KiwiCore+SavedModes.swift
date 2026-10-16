import Foundation

/// What the ACTIVE profile records for a space's layout — the
/// read side of the two profile writes.
///
/// Split from `KiwiCore+Profiles.swift` at the §2.1 hard
/// ceiling. Two shapes of one question, and the difference is
/// load-bearing (#1179): a Layout menu asks a flattened one, where
/// a space the profile omits reads as the genuine `.bsp` default;
/// the GUI draft's seed asks the sparse one, because it writes a
/// FILE from the answer and a space the profile never carried
/// must keep its live mode.
extension KiwiCore {
    /// Saved layout modes for `spaces` under the active profile,
    /// read in **one** pass (#752).
    ///
    /// A space **absent** from the returned dictionary is
    /// "unknown": no active profile. A space absent from the
    /// profile is the genuine `.bsp` default and comes back as
    /// `.bsp` — so the
    /// two conditions stay distinguishable, which is what keeps a
    /// phantom drift off the menu.
    ///
    /// Read from adoption state, never the file (#1245): the Layout
    /// menus ask on every open and the Space Bar's per VoiceOver
    /// query (#1518), where a file read — and a migration write —
    /// per chip focus is the cost that rule forbids.
    public func savedModes(
        for spaces: [SpaceID]
    ) -> [SpaceID: LayoutMode] {
        guard let stored = profiles.liveSpaceModes else { return [:] }
        var modes: [SpaceID: LayoutMode] = [:]
        // A temporary or held Space has no saved layout to drift
        // from, so Keep never arms on one (#1790).
        for space in spaces
        where !isTemporary(space) && state.heldSpaces[space] == nil {
            modes[space] = stored[space] ?? .bsp
        }
        return modes
    }

    /// The active profile's own `spaceModes`, SPARSE — nil for
    /// no readable profile, and no entry for a space the profile
    /// does not carry.
    ///
    /// The distinction the flattening above deliberately loses
    /// (#1179): a space the profile omits is not the same
    /// question as a space it records as `.bsp`, and the GUI
    /// draft's seed writes a FILE from its answer. A live space
    /// the profile never carried — an un-pruned survivor of a
    /// monitor-change apply, or a `gui.json`-seeded one — must
    /// keep its live mode rather than be reset. The menu's
    /// unknown-vs-default question is the other shape and stays
    /// above.
    public func savedProfileModes() -> [SpaceID: LayoutMode]? {
        guard let name = profiles.currentName,
            let profile = try? profiles.read(name: name)
        else { return nil }
        return profile.spaceModes
    }
}
