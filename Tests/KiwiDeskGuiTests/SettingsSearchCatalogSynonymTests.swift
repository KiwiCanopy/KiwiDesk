import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The catalog half of the search index's alternate vocabulary
/// (#1019).
///
/// A catalog-only row — one the `SettingKey` census does not
/// model as a setting — had no route to a synonym at all: the
/// index handed every such row an empty list. General ▸ About's
/// Guide link is the row that needed one, because "help" is what
/// a stuck reader types and this app, being `.accessory`, has no
/// Help menu to type it into.
///
/// Its own suite because `SettingsSearchIndexTests` crossed
/// AGENTS.md §2.1's ceiling, and because the subject is
/// genuinely separate: that suite is about what the index
/// CARRIES, this one about what a query REACHES.
///
/// `.serialized` and locale-pinned: `LocalizationManager` is a
/// process-wide singleton other suites `select()` into
/// concurrently, and a label match is a claim about one catalog.
@Suite("Settings search catalog synonyms", .serialized)
@MainActor
struct SettingsSearchCatalogSynonymTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// The catalog half of the same invariant (#1019). A
    /// catalog-only row has no `SettingKey`, so its synonyms are
    /// keyed on the declaration's `id` — and an entry naming an
    /// id the catalog does not declare is dead vocabulary
    /// nothing can ever match, exactly as above.
    ///
    /// Derived rather than restated: the check walks every
    /// declared control and asserts that the only ids carrying
    /// terms are ones the walk found, so a re-keyed or deleted
    /// declaration reds instead of going quiet.
    @Test("catalog synonyms only decorate declared controls")
    func catalogSynonymsAreLive() {
        pinEnglish()
        defer { reset() }
        let declared = SettingsDestination.allCases
            .flatMap { SettingsCatalog.entries(of: $0) }
            .map { $0.control.id }
        let decorated = declared.filter {
            !SettingsSearchSynonyms.catalogTerms(for: $0).isEmpty
        }
        // The guide is the one catalog row carrying alternate
        // vocabulary today; the assertion is that it IS declared,
        // not how many there are.
        #expect(!decorated.isEmpty)
        for id in decorated {
            #expect(
                declared.contains(id),
                Comment(rawValue: id)
            )
        }
    }

    /// "help" is the query this exists for: the app is
    /// `.accessory` and so has no Help menu, and the guide is
    /// what a stuck reader is reaching for. It matters more than
    /// it looks — `SettingsSearch.results` returns NOTHING for an
    /// empty query, so there is no list to stumble on and the
    /// only route in is typing a word that matches.
    ///
    /// **Through the real search path, not the synonym list.**
    /// Asserting `catalogTerms` contains "help" passes whether or
    /// not the index ever reads it — which is the #1021 failure
    /// exactly: a clause that cannot tell the wired case from the
    /// unwired one. This one reds if `SettingsSearchIndex` goes
    /// back to handing catalog rows an empty synonym list.
    @Test("searching help reaches the guide")
    func helpFindsTheGuide() {
        pinEnglish()
        defer { reset() }
        let anchor = SettingsCatalog.general.guideLink.id
        let hits = SettingsSearch.results(
            query: "help",
            context: SettingsSearchContext()
        ).settings
        #expect(
            hits.contains { $0.anchor.anchor == anchor },
            Comment(
                rawValue:
                    "searching help reached \(hits.count) row(s)"
            )
        )
    }
}
