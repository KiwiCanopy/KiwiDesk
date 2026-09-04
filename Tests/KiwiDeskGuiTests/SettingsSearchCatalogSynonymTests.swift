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
    /// vocabulary, and each one is ruled.**
    ///
    /// The first cut of this asserted `declared.contains(id)`
    /// over a set built by filtering `declared` — true by
    /// construction, so only its non-empty check could ever fail
    /// (`code-reviewer`, 2026-08-26). That is #1021's lesson in
    /// miniature: a clause that cannot distinguish the defect
    /// from the fix.
    ///
    /// What CAN fail, and is worth failing on: a control taking
    /// terms nobody ruled on, and — the harm this was written
    /// for — one silently borrowing ANOTHER's vocabulary, which
    /// would send "help" somewhere other than the guide.
    ///
    /// It was a single-element pin until #1125, when the two
    /// Desktop offers earned terms of their own: they are the
    /// entire search surface for families whose rows are
    /// `.dynamic` and therefore unindexable, so the vocabulary a
    /// user arrives with — Apple's "Mission Control", the
    /// retired nouns — has to reach them or nothing does. A
    /// register with the reason beside each entry holds that
    /// without going back to a claim nothing can check.
    /// Each decorated control, the CONCEPT its terms belong to,
    /// and why it has any. Terms may be shared within a concept
    /// — two doors onto macOS Desktops both answer to "mission
    /// control", and a user typing it wants both — and never
    /// across two, which is how "help" would stop reaching the
    /// guide.
    private var decoratedControls: [String: (String, String)] {
        [
            SettingsCatalog.general.guideLink.id: (
                "guide",
                "the app's one permanent route to the guide"
            ),
            SettingsCatalog.shortcuts.focusDesktops.control.id: (
                "macos-desktops",
                "the only search-reachable name its family has"
            ),
            SettingsCatalog.shortcuts.moveWindowsDesktops.control
                .id: (
                    "macos-desktops",
                    "likewise, the move half of the pair"
                ),
        ]
    }

    @Test("only ruled controls carry catalog synonyms")
    func decoratedControlsAreRuled() {
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
            Set(decorated) == Set(decoratedControls.keys),
            Comment(
                rawValue:
                    "catalog synonyms decorate \(decorated); "
                    + "every one owes a reason in this register"
            )
        )
        // The harm the register exists for: a term reaching
        // ACROSS concepts. Within one, sharing is the point.
        for id in decorated {
            let mine = Set(
                SettingsSearchSynonyms.catalogTerms(for: id)
            )
            #expect(!mine.isEmpty)
            for other in decorated
            where other != id
                && decoratedControls[other]?.0
                    != decoratedControls[id]?.0
            {
                #expect(
                    mine.isDisjoint(
                        with: Set(
                            SettingsSearchSynonyms.catalogTerms(
                                for: other
                            )
                        )
                    ),
                    Comment(
                        rawValue:
                            "\(id) and \(other) name different "
                            + "concepts and share a search term"
                    )
                )
            }
        }
        // Vacuity: the cross-concept arm must be reachable, or
        // the loop above proves nothing about a one-concept
        // register.
        #expect(Set(decoratedControls.values.map(\.0)).count > 1)
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
