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

    @Test("a destination-title match carries no caption")
    func titleMatch() {
        pinEnglish()
        defer { reset() }
        let results = SidebarSearch.results(
            query: "Appearance",
            editingStoredProfile: false
        )
        #expect(
            results
                == [
                    SidebarSearchResult(
                        destination: .appearance,
                        subsection: nil
                    )
                ]
        )
    }

    @Test("a subsection match names the matched header")
    func subsectionMatch() {
        pinEnglish()
        defer { reset() }
        let results = SidebarSearch.results(
            query: "gaps",
            editingStoredProfile: false
        )
        #expect(
            results
                == [
                    SidebarSearchResult(
                        destination: .appearance,
                        subsection: "Gaps"
                    )
                ]
        )
    }

    @Test("matching is case-insensitive substring")
    func caseInsensitiveSubstring() {
        pinEnglish()
        defer { reset() }
        let results = SidebarSearch.results(
            query: "obAl coLo",
            editingStoredProfile: false
        )
        #expect(results.map(\.destination) == [.appBar])
        #expect(results.first?.subsection == "Global colors")
    }

    @Test("a mode-gated editor hit names the mode tab")
    func modeEditorHit() {
        pinEnglish()
        defer { reset() }
        let results = SidebarSearch.results(
            query: "Monocle",
            editingStoredProfile: false
        )
        #expect(
            results
                == [
                    SidebarSearchResult(
                        destination: .layoutDefaults,
                        subsection: "Monocle"
                    )
                ]
        )
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

    @Test("editing a stored profile hides General (#18)")
    func reachabilityFilter() {
        pinEnglish()
        defer { reset() }
        let live = SidebarSearch.results(
            query: "Language",
            editingStoredProfile: false
        )
        #expect(live.map(\.destination) == [.general])
        let editing = SidebarSearch.results(
            query: "Language",
            editingStoredProfile: true
        )
        #expect(editing.isEmpty)
    }

    @Test("every destination lists at least one subsection")
    func indexCoversEveryDestination() {
        pinEnglish()
        defer { reset() }
        for destination in SettingsDestination.allCases {
            #expect(
                !SidebarSearch.subsections(of: destination)
                    .isEmpty,
                "\(destination) has no index entries"
            )
        }
    }
}
