import Testing

@testable import KiwiDesk

/// The one search-matching predicate, pinned from both sides:
/// what it must find, and what it must NOT (it is substring, never
/// fuzzy).
@Suite("Settings search matching")
struct SettingsSearchMatchTests {
    /// The case this was written for. A compounding language
    /// hyphenates where a user types a space, so someone reading
    /// "Space Bar-Farben" and typing what they see found nothing.
    @Test(
        "a separator difference still matches",
        arguments: [
            ("Space Bar-Farben", "space bar farben"),
            ("Space Bar-Farben", "bar farben"),
            ("App Bar-Vorschau: %1$@-Position", "app bar vorschau"),
            // The reverse direction, and the English case that was
            // already broken before any translation existed.
            ("App Bar", "app-bar"),
            ("Per-edge…", "per edge"),
            ("Per-edge…", "per-edge"),
            // Non-breaking space and en/em dashes count too.
            ("Space\u{00a0}Bar", "space bar"),
            ("Space\u{2013}Bar", "space bar"),
            ("Space Bar", "space\u{2014}bar"),
            // A doubled space is a separator run, not two.
            ("Space  Bar", "space bar"),
        ]
    )
    func separatorInsensitive(subject: String, query: String) {
        #expect(subject.searchMatches(query))
    }

    /// Inherited from `localizedStandardContains`, and asserted
    /// because `SidebarSearch`'s documentation claims it.
    @Test(
        "case and diacritics are insensitive",
        arguments: [
            ("Leuchtgröße", "grosse"),
            ("Leuchtgröße", "GRÖSSE"),
            ("Größe", "grosse"),
            ("Global colors", "obAl coLo"),
        ]
    )
    func caseAndDiacriticInsensitive(
        subject: String,
        query: String
    ) {
        #expect(subject.searchMatches(query))
    }

    /// The other side of the contract. Substring is predictable;
    /// a mistype should return nothing rather than a confident
    /// wrong answer, so none of these may start matching.
    @Test(
        "matching is substring, never fuzzy",
        arguments: [
            // A dropped separator is not a match.
            ("Space Bar-Farben", "spacebar"),
            ("App Bar", "appbar"),
            // No edit distance, no transposition tolerance.
            ("Space Bar", "spcae bar"),
            ("Gaps", "gasp"),
            // No subsequence matching.
            ("Space Bar colors", "sbc"),
            // Unrelated words stay unrelated.
            ("Space Bar-Farben", "app bar"),
        ]
    )
    func notFuzzy(subject: String, query: String) {
        #expect(!subject.searchMatches(query))
    }

    /// A dot is deliberately NOT a separator: the app picker
    /// matches on bundle id, which is how an app stays findable by
    /// its habitual English name when the display name is
    /// localized. Collapsing dots would blur that.
    @Test("a dot is not a separator")
    func dotIsNotASeparator() {
        #expect("com.apple.preview".searchMatches("apple.preview"))
        #expect(!"com.apple.preview".searchMatches("apple preview"))
    }

    @Test("normalization does not alter the display text")
    func normalizationIsComparisonOnly() {
        // The sidebar uses the ORIGINAL text as its scroll anchor
        // id, so the normalized form must never leak out of the
        // comparison.
        let label = "Space Bar-Farben"
        #expect(label.searchNormalized == "Space Bar Farben")
        #expect(label == "Space Bar-Farben")
    }
}
