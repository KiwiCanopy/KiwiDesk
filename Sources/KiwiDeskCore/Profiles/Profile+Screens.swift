/// What a SAVED profile can say about its own screens (#789) —
/// the stored-profile twin of
/// `StandardLayout.openingMode(onScreen:screens:)`.
///
/// It exists so the Settings row and the preset card can draw
/// ONE picture grammar. The saved rows drew featureless
/// rectangles only because nothing answered this question, and
/// the two surfaces then said the same thing — "what shape is
/// this profile" — two ways, one scroll apart.
///
/// **A stored profile can answer less than a preset can, and
/// this returns `nil` rather than guessing.** A preset plans
/// positionally (`spaceScreens` names screen 0, 1, 2), so it
/// always knows which screen a space is for. A stored profile
/// pins spaces to *fingerprints* (`MonitorSet.spaceMonitorMap`)
/// and leaves the rest to the Main role plus the positional
/// default — and **which monitor is Main is resolved live, not
/// stored** (`Profile.mainSpaces`' doc comment). So for a
/// multi-screen profile whose spaces were never pinned, no
/// stored fact says which screen opens in what, and inventing
/// one would put a claim about behaviour on screen that loading
/// the profile might not produce.
///
/// That is the same rule `PresetScreenCard.outlineView` already
/// draws by: a screen with no answer gets its outline and no
/// glyph.
extension Profile {
    /// One entry per screen this profile covers, in the stored
    /// set's canonical monitor order — the mode that screen's
    /// first space opens in, or `nil` where the profile does not
    /// say.
    ///
    /// The single-screen case is exact and is the common one:
    /// with one monitor every declared space is on it, so the
    /// first ordered space IS what that screen opens in, pins or
    /// no pins.
    public func openingModes() -> [LayoutMode?] {
        let screens = monitorCount
        guard screens > 0 else { return [] }
        guard screens > 1 else {
            return [orderedSpaces.first.flatMap { spaceModes[$0] }]
        }
        guard let set = monitorSets.first else {
            return Array(repeating: nil, count: screens)
        }
        return set.monitors.prefix(screens).map { fingerprint in
            firstSpace(pinnedTo: fingerprint, in: set)
                .flatMap { spaceModes[$0] }
        }
    }

    /// The profile's own order decides which space is "first" on
    /// a monitor, never the dictionary's — `spaceMonitorMap` is
    /// a `[SpaceID: String]`, and iterating it would pick a
    /// different space between launches for the same profile.
    private func firstSpace(
        pinnedTo fingerprint: String,
        in set: MonitorSet
    ) -> SpaceID? {
        orderedSpaces.first {
            set.spaceMonitorMap[$0] == fingerprint
        }
    }
}
