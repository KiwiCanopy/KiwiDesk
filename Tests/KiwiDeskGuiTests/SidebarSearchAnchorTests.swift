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

    /// Anchor identity is the label TEXT (see `SettingsAnchor`),
    /// so two entries in one destination sharing a label are one
    /// `.id` in one `ScrollView`: `scrollTo` picks undefined which,
    /// and — worse, because it is visible — the flash matches by
    /// text, so *every* view carrying that label washes at once.
    ///
    /// This is the tripwire for the per-control catalog. Text is
    /// sound for the 38 header-level anchors and provably unsound
    /// one level down: Appearance alone renders "Color" six times
    /// simultaneously (focused and unfocused border, plus the
    /// ghost and drop-zone columns' border and fill rows), and
    /// `SlotSizeRows.sizeLabel` even swaps with a sibling picker.
    /// So the catalog cannot land on text identity, and this test
    /// is what stops it doing so quietly.
    @Test("no two entries in a destination share a label")
    func anchorTextsAreUniquePerDestination() {
        pinEnglish()
        defer { reset() }
        var total = 0
        for destination in SettingsDestination.allCases {
            let texts = SidebarSearch.entries(of: destination)
                .map(\.text)
            #expect(!texts.isEmpty)
            #expect(
                texts.count == Set(texts).count,
                Comment(
                    rawValue:
                        "\(destination) has a duplicate anchor "
                        + "label; text identity no longer holds: "
                        + texts.sorted().joined(separator: ", ")
                )
            )
            total += texts.count
        }
        // Pinned, so shrinking the index cannot make the sweep
        // above vacuous while still passing. 44 entries from 38
        // literal `L()` keys in the index files — the six mode
        // tabs come from `LayoutMode.placementTabs`, so
        // `SidebarSearchParityTests` counts 38 where this counts
        // 44. Both numbers are deliberate.
        #expect(total == 44)
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
                case .layoutMode(let mode):
                    #expect(destination == .layoutDefaults)
                    // Floating has no tab (it renders
                    // `EmptyView`), so selecting it would reveal
                    // nothing — the case alone is not enough.
                    #expect(
                        LayoutMode.placementTabs.contains(mode)
                    )
                case .bar:
                    #expect(destination == .bars)
                }
            }
        }
    }
}
