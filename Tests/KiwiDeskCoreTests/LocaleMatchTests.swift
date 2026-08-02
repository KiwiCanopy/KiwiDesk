import Testing

@testable import KiwiDeskCore

/// "System default" locale resolution (issue #9). Every case
/// writes its own `available` list rather than reading the
/// shipped catalogs: the matcher's job is the BCP-47 arithmetic,
/// and asserting it against the real corpus would make the
/// coverage depend on which languages happen to ship.
@Suite("Locale match")
struct LocaleMatchTests {
    private let catalogs = [
        "de", "es", "fr", "it", "ja", "ko", "pt-BR", "ru",
        "zh-Hans", "zh-Hant",
    ]

    @Test("A region-tagged preference finds its language")
    func regionTruncates() {
        #expect(
            LocaleMatch.best(
                preferences: ["de-DE"],
                available: catalogs
            ) == "de"
        )
        #expect(
            LocaleMatch.best(
                preferences: ["de-AT"],
                available: catalogs
            ) == "de"
        )
    }

    /// The bug this whole matcher exists for: matching on the
    /// bare language subtag collapses both Chinese catalogs to
    /// `zh`, which is in `available` under neither name — so a
    /// Chinese system fell through to English however complete
    /// the catalog was.
    @Test("Chinese keeps its script, written either way")
    func chineseKeepsScript() {
        #expect(
            LocaleMatch.best(
                preferences: ["zh-Hant-TW"],
                available: catalogs
            ) == "zh-Hant"
        )
        // Short form: only `maximalIdentifier` knows TW implies
        // Traditional. Widening a bare `zh` would answer
        // Simplified here, which is the wrong language rather
        // than a coarser fallback.
        #expect(
            LocaleMatch.best(
                preferences: ["zh-TW"],
                available: catalogs
            ) == "zh-Hant"
        )
        #expect(
            LocaleMatch.best(
                preferences: ["zh-CN"],
                available: catalogs
            ) == "zh-Hans"
        )
    }

    @Test("A bare language widens onto a refining catalog")
    func widensToRefinement() {
        // No `pt` catalog ships, only `pt-BR`.
        #expect(
            LocaleMatch.best(
                preferences: ["pt"],
                available: catalogs
            ) == "pt-BR"
        )
        #expect(
            LocaleMatch.best(
                preferences: ["pt-PT"],
                available: catalogs
            ) == "pt-BR"
        )
        // A bare `zh` does NOT exercise widening, despite looking
        // like the obvious case: `maximalIdentifier` turns it into
        // `zh-Hans-CN`, which truncates onto the `zh-Hans` catalog
        // exactly. Kept as a regression on that, not as evidence
        // about `widen`.
        #expect(
            LocaleMatch.best(
                preferences: ["zh"],
                available: catalogs
            ) == "zh-Hans"
        )
    }

    /// Widening picks the alphabetically first refinement, so the
    /// answer cannot depend on the order a directory listing
    /// happened to yield.
    ///
    /// This needs two refining catalogs to say anything: with one
    /// `pt-*` shipped, dropping the `.sorted()` the docstring
    /// argues for changes no result, and the shipped set has
    /// exactly one. So the fixture supplies both Portuguese
    /// catalogs and passes them in the *wrong* order.
    @Test("Widening is ordered, not whatever came first")
    func widenIsDeterministic() {
        let reversed = ["pt-PT", "pt-BR"]
        #expect(
            LocaleMatch.best(
                preferences: ["pt"],
                available: reversed
            ) == "pt-BR"
        )
        // And the same answer from the other input order, which is
        // the whole claim.
        #expect(
            LocaleMatch.best(
                preferences: ["pt"],
                available: ["pt-BR", "pt-PT"]
            ) == "pt-BR"
        )
    }

    /// English ships no catalog — it lives inline at the call
    /// sites — so it can only be expressed as `nil`. Without the
    /// short-circuit an English-first user silently gets their
    /// *second* language.
    @Test("English wins at its own position, not the next one")
    func englishShortCircuits() {
        #expect(
            LocaleMatch.best(
                preferences: ["en-DE", "de-DE"],
                available: catalogs
            ) == nil
        )
        #expect(
            LocaleMatch.best(
                preferences: ["en"],
                available: catalogs
            ) == nil
        )
    }

    @Test("An unshipped top preference defers to the next one")
    func walksThePreferenceOrder() {
        // Catalan ships no catalog; German is the real answer,
        // and English sits behind it.
        #expect(
            LocaleMatch.best(
                preferences: ["ca-ES", "de-DE", "en-US"],
                available: catalogs
            ) == "de"
        )
    }

    @Test("No shipped language in the list means English")
    func noMatchIsEnglish() {
        #expect(
            LocaleMatch.best(
                preferences: ["ca-ES", "nb-NO"],
                available: catalogs
            ) == nil
        )
        #expect(
            LocaleMatch.best(preferences: [], available: catalogs)
                == nil
        )
        #expect(
            LocaleMatch.best(
                preferences: ["de-DE"],
                available: []
            ) == nil
        )
    }
}
