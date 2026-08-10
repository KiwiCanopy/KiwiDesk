import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Matching semantics for the per-setting search (#678 turn 11,
/// replacing the sidebar-era one-hit-per-destination cap):
/// substring over localized labels and English synonyms, results
/// in destination order, reachability-filtered (#18), Places
/// capped. English is pinned at the top of every test body — the
/// assertions compare against the inline English at the call
/// sites, and neither the host machine's UI language nor a
/// concurrently running locale suite may leak in (a synchronous
/// body can't be interleaved; an `init` pin can). `.serialized` +
/// reset mirror `KeybindingLocalizationTests` (process-wide
/// singleton).
@Suite("Settings search", .serialized)
@MainActor
struct SettingsSearchTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    private func settings(
        _ query: String,
        context: SettingsSearchContext = SettingsSearchContext()
    ) -> [SettingsSearchResult] {
        SettingsSearch.results(query: query, context: context)
            .settings
    }

    @Test("empty and whitespace queries return nothing")
    func emptyQuery() {
        pinEnglish()
        defer { reset() }
        for query in ["", "   ", "\n"] {
            let results = SettingsSearch.results(
                query: query,
                context: SettingsSearchContext()
            )
            #expect(results.settings.isEmpty)
            #expect(results.places.isEmpty)
        }
    }

    @Test("a destination-title match leads its area's rows")
    func titleMatch() {
        pinEnglish()
        defer { reset() }
        let results = settings("Gaps & Borders")
        #expect(
            results.first
                == .destination(.gapsAndBorders)
        )
    }

    /// The rework's point: one query, every matching setting —
    /// the old cap answered "gap" with a single row.
    @Test("a query returns every matching setting, not one")
    func perSettingResults() {
        pinEnglish()
        defer { reset() }
        let results = settings("gap")
        let keys = results.compactMap { result -> SettingKey? in
            guard case .setting(let row) = result else {
                return nil
            }
            return row.key
        }
        // The per-edge rows at least — one setting each.
        #expect(keys.contains(.gaps(.outer)))
        #expect(keys.contains(.gaps(.inner)))
        #expect(keys.count > 2)
    }

    @Test("results come in destination order")
    func destinationOrder() {
        pinEnglish()
        defer { reset() }
        // "o" is broad on purpose — many destinations match.
        let destinations = settings("o").map(\.destination)
        let order =
            SettingsDestination.thisProfile
            + SettingsDestination.wholeApp
        let positions = destinations.compactMap {
            order.firstIndex(of: $0)
        }
        #expect(positions == positions.sorted())
    }

    @Test("matching is case-insensitive substring")
    func caseInsensitiveSubstring() {
        pinEnglish()
        defer { reset() }
        let results = settings("pP bAr cOlo")
        #expect(!results.isEmpty)
        #expect(
            results.allSatisfy {
                $0.destination == .advancedColors
            }
        )
    }

    /// A synonym matches without appearing anywhere on screen —
    /// English match-only vocabulary (`SettingsSearchSynonyms`).
    @Test("an English synonym finds its setting")
    func synonymMatch() {
        pinEnglish()
        defer { reset() }
        let results = settings("autostart")
        let hit = results.contains { result in
            guard case .setting(let row) = result else {
                return false
            }
            return row.key == .general(.startAtLogin)
        }
        #expect(hit)
    }

    @Test("editing a stored profile hides General rows (#18)")
    func reachabilityFilter() {
        pinEnglish()
        defer { reset() }
        let live = settings("Applies immediately")
        #expect(live.map(\.destination) == [.general])
        let editing = settings(
            "Applies immediately",
            context: SettingsSearchContext(
                editingStoredProfile: true
            )
        )
        #expect(editing.isEmpty)
    }

    @Test("every destination lists at least one entry")
    func indexCoversEveryDestination() {
        pinEnglish()
        defer { reset() }
        for destination in SettingsDestination.allCases {
            #expect(
                !SettingsCatalog.entries(of: destination).isEmpty,
                "\(destination) has no catalog entries"
            )
        }
    }

    @Test("a drawer's own words reach its destination")
    func drawerSpecificTermsResolve() {
        pinEnglish()
        defer { reset() }
        for (query, destination) in [
            ("fingerprint", SettingsDestination.monitors),
            ("per-edge", .gapsAndBorders),
            ("drop zone", .gapsAndBorders),
            ("lua bindings", .shortcuts),
        ] {
            let results = settings(query)
            #expect(
                results.contains {
                    $0.destination == destination
                },
                Comment(rawValue: query)
            )
        }
    }

    /// The pill's predicate is the ONE offer predicate
    /// (`HomeCardOrder.isOffered`), never a hand-negated copy:
    /// a Power-User-only area flips in Simple mode, stays quiet
    /// in Power User mode, and the Monitors display-count
    /// promotion silences its pill exactly when it silences its
    /// gate.
    @Test("the mode pill derives from the offer predicate")
    func modePillFollowsOfferPredicate() {
        pinEnglish()
        defer { reset() }
        let simple = SettingsSearchContext(mode: .simple)
        let power = SettingsSearchContext(mode: .powerUser)
        let advanced = SettingsSearchResult.destination(
            .advancedColors
        )
        #expect(
            SettingsSearch.switchesMode(advanced, context: simple)
        )
        #expect(
            !SettingsSearch.switchesMode(advanced, context: power)
        )
        let monitors = SettingsSearchResult.destination(.monitors)
        #expect(
            SettingsSearch.switchesMode(monitors, context: simple)
        )
        #expect(
            !SettingsSearch.switchesMode(
                monitors,
                context: SettingsSearchContext(
                    mode: .simple,
                    displayCount: 2
                )
            )
        )
        let simpleArea = SettingsSearchResult.destination(.bars)
        #expect(
            !SettingsSearch.switchesMode(
                simpleArea,
                context: simple
            )
        )
    }
}
