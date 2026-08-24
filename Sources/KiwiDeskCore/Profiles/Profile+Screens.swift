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
///
/// **But "no fingerprint names Main" is not the same as "the
/// profile does not say" (#959).** Every ordinary two-screen
/// profile hits that gap: saving pins only the spaces that are
/// NOT on the main display (`adoptComposedPlacement`), so the
/// main monitor is precisely the covered one carrying no pin,
/// and its pip drew blank beside a caption announcing six
/// Spaces. Where exactly ONE covered monitor has no pin, the
/// follows-main spaces have nowhere else to be — the answer
/// comes out by elimination, not by a guess about hardware, and
/// it is as stored as any pin. Two blank monitors stay blank:
/// then the unpinned spaces could be on either, and that IS the
/// refusal above.
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
        var firsts = set.monitors.prefix(screens).map {
            firstSpace(pinnedTo: $0, in: set)
        }
        if let main = soleUnpinnedScreen(in: firsts),
            let space = firstMainSpace()
        {
            firsts[main] = space
        }
        return firsts.map { $0.flatMap { spaceModes[$0] } }
    }

    /// The index of the one covered monitor carrying no pin —
    /// nil unless there is exactly one.
    ///
    /// Exactly one is the whole condition: with two unpinned
    /// monitors the follows-main spaces fit on either, so
    /// attributing them to one would be the guess this accessor
    /// exists to refuse.
    private func soleUnpinnedScreen(
        in firsts: [SpaceID?]
    ) -> Int? {
        let blank = firsts.indices.filter { firsts[$0] == nil }
        return blank.count == 1 ? blank.first : nil
    }

    /// The profile's first ordered follows-main space.
    ///
    /// The profile's own order again, for the reason
    /// `firstSpace(pinnedTo:in:)` states — `mainSpaces` is a
    /// stored list, but it is a list of MEMBERS, and which of
    /// them comes first is `orderedSpaces`' answer, not its own.
    private func firstMainSpace() -> SpaceID? {
        let main = Set(mainSpaces)
        return orderedSpaces.first { main.contains($0) }
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
