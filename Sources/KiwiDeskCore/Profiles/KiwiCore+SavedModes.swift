import Foundation

/// What the ACTIVE profile records for a space's layout — the
/// read side of the two profile writes.
///
/// Split from `KiwiCore+Profiles.swift` at the §2.1 hard
/// ceiling. Two shapes of one question, and the difference is
/// load-bearing (#1179): the menu asks a flattened one, where a
/// space the profile omits reads as the genuine `.bsp` default;
/// the GUI draft's seed asks the sparse one, because it writes a
/// FILE from the answer and a space the profile never carried
/// must keep its live mode.
extension KiwiCore {
    /// Saved layout mode for the active space under the active
    /// profile. nil when no profile is active or its JSON is
    /// unreadable — "unknown", never a phantom `.bsp` that
    /// would fake drift; an absent entry (a readable profile
    /// without the space) is the genuine `.bsp` default.
    public func savedModeForActiveSpace() -> LayoutMode? {
        guard let space = activeSpace else { return nil }
        // Expressed through the batch rather than beside it: the
        // two carried the same `?? .bsp` default and the same
        // unknown-vs-default distinction, kept in agreement by
        // prose alone. `profiles.md` already rules that an
        // unlisted mode should follow the screen rather than a
        // fixed bsp (`SparseModeFallbackTests`), and that change
        // would otherwise have to be made twice — with the menu
        // showing phantom drift on whichever path was missed
        // (`architect-reviewer`, 2026-08-17).
        return savedModes(for: [space.id])[space.id]
    }

    /// Saved layout modes for `spaces` under the active profile,
    /// read in **one** pass (#752).
    ///
    /// The quick menu asks about every connected screen's shown
    /// space at once, and the single-space call above re-reads the
    /// profile JSON per question — three screens would be three
    /// file reads on every menu open. One read answers all of
    /// them.
    ///
    /// A space **absent** from the returned dictionary is
    /// "unknown", exactly as a nil from the call above is: no
    /// active profile, or JSON that would not decode. A space
    /// absent from a *readable* profile is the genuine `.bsp`
    /// default and comes back as `.bsp` — so the two conditions
    /// stay distinguishable, which is what keeps a phantom drift
    /// off the menu.
    public func savedModes(
        for spaces: [SpaceID]
    ) -> [SpaceID: LayoutMode] {
        guard let stored = savedProfileModes() else { return [:] }
        var modes: [SpaceID: LayoutMode] = [:]
        for space in spaces {
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
