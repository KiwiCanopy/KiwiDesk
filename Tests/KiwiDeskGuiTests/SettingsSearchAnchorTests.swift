import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a search hit LANDS on (#277 tier 2, per-setting since
/// #678 turn 11): the anchor id a hit scrolls to, the local
/// surface it must select first, and the breadcrumb above it.
/// Split from `SettingsSearchTests`, which owns matching
/// semantics (AGENTS.md §5, split suites early). English pinned
/// at each test body's start, per the #90 convention — an `init`
/// pin races the locale suites.
///
/// Anchor identity is `SettingsControl.id`, never the label text
/// (see `SettingsAnchor`); id uniqueness and surface fit are
/// pinned catalog-side in `SettingsCatalogTests`.
@Suite("Settings search anchors", .serialized)
@MainActor
struct SettingsSearchAnchorTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    private func rows(
        _ query: String
    ) -> [SettingsSearchIndexRow] {
        SettingsSearch.results(
            query: query,
            context: SettingsSearchContext()
        )
        .settings
        .compactMap {
            guard case .setting(let row) = $0 else { return nil }
            return row
        }
    }

    /// The fix #277 exists for: tier 1 could only *name* the mode
    /// tab in a caption and leave the click to the user. A mode
    /// tab is a catalog-only anchor row (`key == nil`) — the
    /// census has no setting for a tab.
    @Test("a mode-gated hit carries its mode tab")
    func modeSurface() {
        pinEnglish()
        defer { reset() }
        let row = rows("Monocle").first {
            $0.anchor.anchor == "layout_mode/monocle"
        }
        #expect(row != nil)
        #expect(row?.key == nil)
        #expect(row?.destination == .layoutDefaults)
        #expect(
            row?.anchor
                == SettingsAnchor(
                    destination: .layoutDefaults,
                    surface: .layoutMode(.monocle),
                    anchor: "layout_mode/monocle"
                )
        )
        // The mode is the match itself, so it is not repeated
        // above itself in the breadcrumb.
        #expect(row?.path == ["Layout Defaults"])
    }

    /// The bare bar name is findable via the two switch chips
    /// (#277): the one Bars page (turn 7a) means no surface to
    /// select — searching "App Bar" reaches that card among its
    /// results.
    @Test("a bare bar-name search reaches the bar's card")
    func barNameHitsCard() {
        pinEnglish()
        defer { reset() }
        for (query, anchor) in [
            ("App Bar", "bars.switch.app_bar"),
            ("Space Bar", "bars.switch.space_bar"),
        ] {
            let row = rows(query).first {
                $0.anchor.anchor == anchor
            }
            #expect(row != nil, Comment(rawValue: query))
            #expect(
                row?.anchor.surface == .main,
                Comment(rawValue: query)
            )
            // The chip's own name IS the match, so the breadcrumb
            // is the destination alone — not "Bars › App Bar ›
            // App Bar".
            #expect(
                row?.path == ["Bars"],
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
        let row = rows("Top").first {
            $0.anchor.anchor == "gaps.top"
        }
        #expect(row != nil)
        #expect(row?.destination == .gapsAndBorders)
        #expect(row?.label == "Top")
        #expect(
            row?.path == ["Gaps & Borders", "Per-edge…"]
        )
    }

    /// The twice-mounted shape (both bar cards mount a "Style"
    /// drawer, co-rendered on the one Bars page): each mount has
    /// its own catalog declaration, so a hit's id is
    /// instance-qualified and `scrollTo` is well-defined — and
    /// BOTH instances are results now that the per-destination
    /// cap is gone.
    @Test("per-instance drawer hits carry their instance ids")
    func instanceQualifiedHits() {
        pinEnglish()
        defer { reset() }
        let anchors = rows("Style").compactMap(\.anchor.anchor)
        #expect(anchors.contains("space_bar/bars.style"))
        #expect(anchors.contains("app_bar/bars.style"))
    }

    /// A destination-title hit has no finer target than the tab,
    /// so it must not request a scroll — the #326 deep link takes
    /// this same shape.
    @Test("a destination hit requests no scroll")
    func titleHitHasNoAnchor() {
        pinEnglish()
        defer { reset() }
        let results = SettingsSearch.results(
            query: "Behavior",
            context: SettingsSearchContext()
        ).settings
        guard
            case .destination(let destination) = results.first
        else {
            Issue.record("no destination row for its own title")
            return
        }
        #expect(destination == .behavior)
        let anchor = results.first?.anchor
        #expect(anchor?.anchor == nil)
        #expect(anchor?.surface == .main)
    }

    /// A census-keyed hit lands on the catalog control carrying
    /// its label key: surface, scroll id and drawer expansion
    /// all come from the one declaration the render site
    /// mounts. (A census key whose label key no control carries
    /// lands destination-only — most census rows today, until
    /// the #277 catalog fills; `SettingsSearchIndexTests` pins
    /// the per-destination counts.)
    @Test("a census hit lands on its catalog control")
    func censusHitCarriesCatalogAnchor() {
        pinEnglish()
        defer { reset() }
        let row = rows("Top").first {
            $0.key == .gaps(.outerTop)
        }
        #expect(row != nil)
        #expect(row?.anchor.destination == .gapsAndBorders)
        #expect(row?.anchor.anchor == "gaps.top")
    }

    /// An anchor-less LAYOUT hit still opens ITS tab: the
    /// census id (`settings.<mode>.…`) names the mode, so the
    /// row lands on the Grid tab instead of whatever tab
    /// renders first — the owner hit exactly this with a
    /// German "Spalten" query landing on BSP (2026-08-10). No
    /// scroll id until the #277 catalog carries the control.
    @Test("an anchor-less layout hit opens its mode tab")
    func layoutFallbackSurface() {
        pinEnglish()
        defer { reset() }
        let row = rows("Columns").first {
            $0.key == .layout(.gridColumns)
        }
        #expect(row != nil)
        #expect(row?.anchor.anchor == nil)
        #expect(row?.anchor.surface == .layoutMode(.grid))
        #expect(row?.path == ["Layout Defaults", "Grid"])
    }

    /// The shell's decision, at the one place it is made. Pinned
    /// because `apply` is `private` on a `View` and unreachable,
    /// and because the extraction's stated purpose was to make
    /// exactly these three things testable.
    @Test("a request resolves to what the shell should do")
    func resolvedDecision() {
        pinEnglish()
        defer { reset() }

        // #18: a destination the shell hides is refused outright.
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
