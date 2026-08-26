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

    /// **Exactly one catalog control carries alternate
    /// vocabulary, and it is the guide.**
    ///
    /// The first cut of this asserted `declared.contains(id)`
    /// over a set built by filtering `declared` — true by
    /// construction, so only its non-empty check could ever fail
    /// (`code-reviewer`, 2026-08-26). That is #1021's lesson in
    /// miniature: a clause that cannot distinguish the defect
    /// from the fix.
    ///
    /// What CAN fail, and is worth failing on: terms attached to
    /// a second catalog control. `catalogTerms` is a `guard id ==`
    /// against one declaration, so a widening is a deliberate
    /// edit — and one that silently gives another row the guide's
    /// vocabulary would send "help" somewhere else.
    @Test("only the guide carries catalog synonyms")
    func theGuideIsTheOnlyDecoratedControl() {
        pinEnglish()
        defer { reset() }
        let decorated = SettingsDestination.allCases
            .flatMap { SettingsCatalog.entries(of: $0) }
            .map { $0.control.id }
            .filter {
                !SettingsSearchSynonyms.catalogTerms(for: $0)
                    .isEmpty
            }
        #expect(
            decorated == [SettingsCatalog.general.guideLink.id],
            Comment(
                rawValue:
                    "catalog synonyms decorate \(decorated); the "
                    + "guide is meant to be the only one"
            )
        )
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
