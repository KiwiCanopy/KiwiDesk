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
/// profile does not say" (#959)**, so a sole unpinned screen is
/// answered by elimination. The ruling and its argument are in
/// `docs/design-decisions.md` ▸ Profiles; what this file owes is
/// the seam and the two things elimination is NOT sure of.
///
/// **Residue 1 — a space pinned to the MAIN display.** The
/// GUI's Monitors editor can pin a space onto the main display's
/// own card (`SpaceAssignmentChip`, `DisplayCard`), and Lua's
/// `pin_space_to_display` does the same. Then main carries a pin
/// AND the follows-main spaces, so the sole blank screen is a
/// SECONDARY one that holds nothing — and it borrows Main's
/// glyph. Accepted rather than fixed: nothing stored tells the
/// two apart (which fingerprint was Main is resolved live), and
/// refusing the whole arm to avoid it would cost every ordinary
/// two-screen profile the glyph #959 was filed about. The case
/// is pinned by `ProfileOpeningModesTests` so it is a chosen
/// answer rather than an accident.
///
/// **Residue 2 — a profile covering several arrangements**
/// answers from `monitorSets.first`. That was harmless while the
/// answer was a refusal; elimination makes it a positive claim
/// about one arrangement, and the row carries no per-set label.
/// A screen blank in the first set may be pinned in another.
///
/// Two blank screens stay blank in every case: there the
/// unpinned spaces fit on either, and that IS the refusal above.
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
            let space = firstMainSpace(in: set)
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
    ///
    /// A space carrying a pin is not a candidate even when
    /// `main_spaces` also lists it: `SpacePlacement.resolve`
    /// gives the pin precedence over the Main role, so such a
    /// space opens on the pinned screen, and painting the blank
    /// one with its mode would name a screen it never reaches.
    /// The GUI writers clear one when they set the other; a
    /// hand-edited profile is what can carry both.
    private func firstMainSpace(in set: MonitorSet) -> SpaceID? {
        let main = Set(mainSpaces)
        return orderedSpaces.first {
            main.contains($0) && set.spaceMonitorMap[$0] == nil
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
