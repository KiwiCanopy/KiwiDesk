import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a search hit LANDS on (#277 tier 2): the anchor text a
/// hit scrolls to, the local surface it must select first, and
/// the breadcrumb above it. Split from `SidebarSearchTests`,
/// which owns matching semantics (AGENTS.md §5, split suites
/// early). English pinned at each test body's start, per the #90
/// convention — an `init` pin races the locale suites.
@Suite("Sidebar search anchors", .serialized)
@MainActor
struct SidebarSearchAnchorTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// The fix #277 exists for: tier 1 could only *name* the mode
    /// tab in a caption and leave the click to the user.
    @Test("a mode-gated hit carries its mode tab")
    func modeSurface() {
        pinEnglish()
        defer { reset() }
        let result = SidebarSearch.results(
            query: "Monocle",
            editingStoredProfile: false
        ).first
        #expect(result?.destination == .layoutDefaults)
        #expect(
            result?.anchor
                == SettingsAnchor(
                    destination: .layoutDefaults,
                    surface: .layoutMode(.monocle),
                    anchor: "Monocle"
                )
        )
        // The mode is the match itself, so it is not repeated
        // above itself in the breadcrumb.
        #expect(result?.path == ["Layout Defaults"])
    }

    /// The `.bars` limit tier 1 recorded and could not fix: two
    /// editors behind one switch.
    @Test("each bar hit carries the side of the switch it is on")
    func barSurface() {
        pinEnglish()
        defer { reset() }
        for (query, editor, side) in [
            ("Space Bar style", BarEditor.spaceBar, "Space Bar"),
            ("Global style", .appBar, "App Bar"),
        ] {
            let result = SidebarSearch.results(
                query: query,
                editingStoredProfile: false
            ).first
            #expect(
                result?.anchor.surface == .bar(editor),
                Comment(rawValue: query)
            )
            // Both sides are named, including the default one:
            // which of the two bars was found is the information
            // the user came for.
            #expect(
                result?.path == ["Bars", side],
                Comment(rawValue: query)
            )
        }
    }

    /// A destination-title hit has no finer target than the tab,
    /// so it must not request a scroll — the #326 deep link takes
    /// this same shape.
    @Test("a destination hit requests no scroll")
    func titleHitHasNoAnchor() {
        pinEnglish()
        defer { reset() }
        let result = SidebarSearch.results(
            query: "Behavior",
            editingStoredProfile: false
        ).first
        #expect(result?.anchor.anchor == nil)
        #expect(result?.anchor.surface == .main)
        #expect(result?.path.isEmpty == true)
    }

    /// Every anchor a result can produce must be a string some
    /// view actually tags itself with. `SettingsSection` derives
    /// its `.id` from the title it renders, so the check is that
    /// the anchor text equals an indexed entry's text — the same
    /// value, not a parallel copy. A drifted `path(to:)` that
    /// smuggled a breadcrumb segment into the anchor would fail
    /// here.
    @Test("every anchor is an indexed entry's own text")
    func anchorsAreIndexedText() {
        pinEnglish()
        defer { reset() }
        var checked = 0
        for destination in SettingsDestination.allCases {
            let texts = Set(
                SidebarSearch.entries(of: destination)
                    .map(\.text)
            )
            #expect(!texts.isEmpty)
            for entry in SidebarSearch.entries(of: destination) {
                let result = SidebarSearch.results(
                    query: entry.text,
                    editingStoredProfile: false
                )
                .first { $0.destination == destination }
                guard let result, let anchor = result.anchor.anchor
                else { continue }
                #expect(
                    texts.contains(anchor),
                    Comment(rawValue: "\(destination): \(anchor)")
                )
                checked += 1
            }
        }
        // A zero here would pass every expectation above
        // vacuously. 38 entries today; the floor only has to
        // prove the sweep ran.
        #expect(checked >= 30)
    }

    /// The surface of every entry must be one this destination
    /// can actually show — a `.layoutMode` on Bars would select
    /// nothing and the reveal would scroll to a view that is not
    /// there.
    @Test("entry surfaces belong to their destination")
    func surfacesMatchDestination() {
        pinEnglish()
        defer { reset() }
        for destination in SettingsDestination.allCases {
            for entry in SidebarSearch.entries(of: destination) {
                switch entry.surface {
                case .main:
                    continue
                case .layoutMode:
                    #expect(destination == .layoutDefaults)
                case .bar:
                    #expect(destination == .bars)
                }
            }
        }
    }
}
