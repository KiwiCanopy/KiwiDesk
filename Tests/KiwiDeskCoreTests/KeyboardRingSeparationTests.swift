import Testing

/// The keyboard board's two ring warnings, measured through the
/// same protanopia transform every other palette decision uses.
///
/// The hexes mirror `SettingsTheme` (the colour-vision maths
/// lives in this target and cannot see the GUI's types);
/// `SettingsThemeTokenTests` pins the tokens themselves, so a
/// change there without a change here reds one of the two.
///
/// **Each ring is measured against the ONE fill it can sit on**,
/// which is what makes both possible at all. A reserved ring
/// only ever rings a FREE key — a key the user has bound reads
/// bound whatever macOS thinks — and a conflict ring only ever
/// rings a BOUND one, since a conflict is two bindings on the
/// same key. Measuring each against both grounds would reject
/// colours that are never drawn on the ground that rejects them.
@Suite("Keyboard ring separation")
struct KeyboardRingSeparationTests {
    private let bound = "#B6D95F"
    private let free = "#37463B"
    private let reserved = "#E0A34A"
    private let conflict = "#E87F72"

    @Test("The reserved ring reads on the free key it rings")
    func reservedRingReadsOnFree() throws {
        let separation = try #require(
            ColorVision.separation(reserved, free)
        )
        #expect(separation >= ColorVision.separationFloor)
    }

    @Test("The conflict ring reads on the bound key it rings")
    func conflictRingReadsOnBound() throws {
        let separation = try #require(
            ColorVision.separation(conflict, bound)
        )
        #expect(separation >= ColorVision.separationFloor)
    }

    /// The pairing a hand-rolled CIE-Lab proxy rejected during
    /// the pass, at "42.4" against a floor of 60 — on THIS
    /// metric it is 100.2 and always was. Kept as a standing
    /// reminder that `ColorVision` is the measure and a
    /// re-derivation of it is not: the wrong yardstick cost a
    /// whole redesign of the key fills before anyone ran the
    /// real one.
    @Test("The board's own metric is the one that decides")
    func theRepoMetricIsTheAuthority() throws {
        let separation = try #require(
            ColorVision.separation(conflict, bound)
        )
        #expect(separation > 90)
    }
}
