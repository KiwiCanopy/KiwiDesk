import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a search hit LANDS on (#277 tier 2): the anchor id a hit
/// scrolls to, the local surface it must select first, and the
/// breadcrumb above it. Split from `SidebarSearchTests`, which
/// owns matching semantics (AGENTS.md §5, split suites early).
/// English pinned at each test body's start, per the #90
/// convention — an `init` pin races the locale suites.
///
/// Anchor identity is `SettingsControl.id`, never the label text
/// (see `SettingsAnchor`); id uniqueness and surface fit are
/// pinned catalog-side in `SettingsCatalogTests`.
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
                    anchor: "layout_mode/monocle"
                )
        )
        // The mode is the match itself, so it is not repeated
        // above itself in the breadcrumb.
        #expect(result?.path == ["Layout Defaults"])
    }

    /// The bare bar name is findable via the two cards (#277):
    /// the one Bars page (turn 7a) means no surface to select —
    /// searching "App Bar" scrolls to that card. The card entry
    /// is declared first, so it wins the one-row-per-destination
    /// cap over its own colour card.
    @Test("a bare bar-name search lands on the bar's card")
    func barNameHitsCard() {
        pinEnglish()
        defer { reset() }
        for (query, anchor) in [
            ("App Bar", "bars.switch.app_bar"),
            ("Space Bar", "bars.switch.space_bar"),
        ] {
            let result = SidebarSearch.results(
                query: query,
                editingStoredProfile: false
            ).first
            #expect(
                result?.anchor.surface == .main,
                Comment(rawValue: query)
            )
            #expect(
                result?.anchor.anchor == anchor,
                Comment(rawValue: query)
            )
            // The chip's own name IS the match, so the breadcrumb
            // is the destination alone — not "Bars › App Bar ›
            // App Bar".
            #expect(
                result?.path == ["Bars"],
                Comment(rawValue: query)
            )
        }
    }

    /// A drawer-interior hit (#277 part 2): the anchor is the
    /// row's id, and the breadcrumb names the drawer, since a
    /// bare "Top" says nothing about which control was found.
    /// The expansion itself is pinned in `SettingsCatalogTests`
    /// (`shouldExpand`), which `SettingsDisclosure` consumes.
    @Test("a hit inside a drawer carries its row id and drawer")
    func drawerInteriorHit() {
        pinEnglish()
        defer { reset() }
        let result = SidebarSearch.results(
            query: "Top",
            editingStoredProfile: false
        ).first
        #expect(result?.destination == .gapsAndBorders)
        #expect(result?.anchor.anchor == "gaps.top")
        #expect(result?.primary == "Top")
        #expect(
            result?.path == ["Gaps & Borders", "Per-edge…"]
        )
    }

    /// The twice-mounted shape (both bar cards mount a "Style"
    /// drawer, co-rendered on the one Bars page): each mount has
    /// its own catalog declaration, so the hit's id is
    /// instance-qualified and `scrollTo` is well-defined. First
    /// declaration wins the one-row-per-destination cap — the
    /// Space Bar's, the leading card.
    @Test("a per-instance drawer hit carries its instance id")
    func instanceQualifiedHit() {
        pinEnglish()
        defer { reset() }
        let result = SidebarSearch.results(
            query: "Style",
            editingStoredProfile: false
        ).first
        #expect(result?.destination == .bars)
        #expect(result?.anchor.anchor == "space_bar/bars.style")
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

    /// The shell's decision, at the one place it is made. Pinned
    /// because `apply` is `private` on a `View` and unreachable,
    /// and because the extraction's stated purpose was to make
    /// exactly these three things testable.
    @Test("a request resolves to what the shell should do")
    func resolvedDecision() {
        pinEnglish()
        defer { reset() }

        // #18: a destination the sidebar hides is refused outright.
        #expect(
            SettingsAnchor(destination: .general)
                .resolved(editingStoredProfile: true) == nil
        )
        // …and allowed when it is visible.
        let live = SettingsAnchor(destination: .general)
            .resolved(editingStoredProfile: false)
        #expect(live?.destination == .general)

        // A destination-only request must ask for NO scroll — the
        // #326 bridge's shape.
        #expect(live?.scroll == nil)
        #expect(live?.surface == .main)

        // A surface its destination renders passes through.
        let modes = SettingsAnchor(
            destination: .layoutDefaults,
            surface: .layoutMode(.monocle),
            anchor: "layout_mode/monocle"
        )
        .resolved(editingStoredProfile: false)
        #expect(modes?.surface == .layoutMode(.monocle))
        #expect(modes?.scroll == "layout_mode/monocle")

        // One it cannot degrades to `.main` rather than refusing
        // the whole request: Floating has no tab, so selecting it
        // would render an empty pane.
        #expect(
            SettingsAnchor(
                destination: .layoutDefaults,
                surface: .layoutMode(.floating)
            )
            .resolved(editingStoredProfile: false)?.surface
                == .main
        )
        // Likewise a surface belonging to another destination.
        #expect(
            SettingsAnchor(
                destination: .gapsAndBorders,
                surface: .layoutMode(.monocle)
            )
            .resolved(editingStoredProfile: false)?.surface
                == .main
        )
    }
}
