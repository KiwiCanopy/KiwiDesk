import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Matching semantics for the sidebar search (#90): substring,
/// case-insensitive, one row per destination in sidebar order,
/// reachability-filtered (#18). English is pinned at the top
/// of every test body — the assertions compare against the
/// inline English at the call sites, and neither the host
/// machine's UI language nor a concurrently running locale
/// suite may leak in (a synchronous body can't be interleaved;
/// an `init` pin can). `.serialized` + reset mirror
/// `KeybindingLocalizationTests` (process-wide singleton).
@Suite("Sidebar search", .serialized)
@MainActor
struct SidebarSearchTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    @Test("empty and whitespace queries return nothing")
    func emptyQuery() {
        pinEnglish()
        defer { reset() }
        for query in ["", "   ", "\n"] {
            #expect(
                SidebarSearch.results(
                    query: query,
                    editingStoredProfile: false
                ).isEmpty
            )
        }
    }

    @Test("a destination-title match has no path or anchor")
    func titleMatch() {
        pinEnglish()
        defer { reset() }
        let results = SidebarSearch.results(
            query: "Gaps & Borders",
            editingStoredProfile: false
        )
        #expect(
            results
                == [
                    SidebarSearchResult(
                        destination: .gapsAndBorders,
                        anchor: SettingsAnchor(
                            destination: .gapsAndBorders
                        ),
                        primary: "Gaps & Borders",
                        path: []
                    )
                ]
        )
    }

    @Test("a header match leads with the header")
    func subsectionMatch() {
        pinEnglish()
        defer { reset() }
        let results = SidebarSearch.results(
            query: "sticky",
            editingStoredProfile: false
        )
        #expect(
            results
                == [
                    SidebarSearchResult(
                        destination: .gapsAndBorders,
                        anchor: SettingsAnchor(
                            destination: .gapsAndBorders,
                            anchor: "sticky.title"
                        ),
                        primary: "Sticky windows",
                        path: ["Gaps & Borders"]
                    )
                ]
        )
    }

    @Test("matching is case-insensitive substring")
    func caseInsensitiveSubstring() {
        pinEnglish()
        defer { reset() }
        let results = SidebarSearch.results(
            query: "pp bAr cOlo",
            editingStoredProfile: false
        )
        #expect(results.map(\.destination) == [.advancedColors])
        #expect(results.first?.primary == "App Bar colors")
    }

    @Test("one row per destination, in sidebar order")
    func dedupedSidebarOrder() {
        pinEnglish()
        defer { reset() }
        // "o" hits multiple subsections of several
        // destinations; every destination must still appear
        // at most once, in the sidebar's own order.
        let results = SidebarSearch.results(
            query: "o",
            editingStoredProfile: false
        )
        let destinations = results.map(\.destination)
        #expect(
            destinations.count == Set(destinations).count
        )
        let sidebarOrder =
            SettingsDestination.thisProfile
            + SettingsDestination.wholeApp
        let expected = sidebarOrder.filter {
            destinations.contains($0)
        }
        #expect(destinations == expected)
    }

    /// The subject is the reachability filter, not the word. The
    /// query names a CARD, because that is what the index holds
    /// (destination titles, then catalog declarations — rows are
    /// Phase 4's). It moved off "Language" when turn 14b merged
    /// General's Language and Login cards into one "Applies
    /// immediately" card.
    @Test("editing a stored profile hides General (#18)")
    func reachabilityFilter() {
        pinEnglish()
        defer { reset() }
        let live = SidebarSearch.results(
            query: "Applies immediately",
            editingStoredProfile: false
        )
        #expect(live.map(\.destination) == [.general])
        let editing = SidebarSearch.results(
            query: "Applies immediately",
            editingStoredProfile: true
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

    @Test("a drawer header is reachable, on every tab that has one")
    func drawerHeadersAreReachable() {
        pinEnglish()
        defer { reset() }
        // The #406 gap: drawers were unsearchable. Parity tests
        // compare KEYS, so only this pins the destination
        // mapping — the axis a source scan structurally cannot
        // see (it reads text, not the view tree).
        let results = SidebarSearch.results(
            query: "advanced",
            editingStoredProfile: false
        )
        // Sidebar order. Gaps & Borders is absent on purpose:
        // its drawers are "Per-edge…" / "Per-axis…", neither of
        // which contains "advanced". Monitors and Shortcuts are
        // absent for a newer reason: their drawers dropped the
        // qualifier, because nothing above them is a lesser
        // fingerprint or a lesser Lua binding — "Advanced"
        // prefixes a noun only where a basic tier of that same
        // noun is visible above it (#406). Bars left the list in
        // #678 Phase 3 for exactly that rule: its "Advanced
        // colors" drawers became "More colors" on a page whose
        // own NAME is the qualifier, which is where the word
        // now lands — as a destination title, the better anchor,
        // since destination titles are indexed and drawer titles
        // are hand-listed.
        #expect(
            results.map(\.destination)
                == [.advancedColors, .general]
        )
        for (query, destination) in [
            ("lua bindings", SettingsDestination.shortcuts),
            ("monitor fingerprints", .monitors),
        ] {
            #expect(
                SidebarSearch.results(
                    query: query,
                    editingStoredProfile: false
                ).map(\.destination) == [destination],
                Comment(rawValue: query)
            )
        }
    }

    @Test("a drawer's own words reach its tab")
    func drawerSpecificTermsResolve() {
        pinEnglish()
        defer { reset() }
        for (query, destination) in [
            ("fingerprint", SettingsDestination.monitors),
            ("per-edge", .gapsAndBorders),
            ("drop zone", .gapsAndBorders),
        ] {
            let results = SidebarSearch.results(
                query: query,
                editingStoredProfile: false
            )
            #expect(
                results.map(\.destination) == [destination],
                Comment(rawValue: query)
            )
        }
    }
}
