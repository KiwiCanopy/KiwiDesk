import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where a census hit behind a disclosure LANDS (#277, #1250):
/// on a catalog child its drawer expands for, never on the
/// destination root with the drawer shut. Split from
/// `SettingsSearchAnchorTests`, which owns the surface and
/// breadcrumb rules for the rest of the index. English pinned
/// per body (#90).
@Suite("Settings search drawer anchors", .serialized)
@MainActor
struct SettingsSearchDrawerAnchorTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// One row per drawer the catalog declares WITH children:
    /// the destination and census container whose `.showMore`
    /// rows it hides — a container name recurs across areas
    /// (`.appBar` holds Bars' Style rows AND Advanced Colours'),
    /// so both are named — the drawer, and the breadcrumb a hit
    /// inside it carries. The membership of each container is
    /// the census's, read live, so a new row landing in one of
    /// them anchor-less reds here without a count. A drawer
    /// joining the catalog with children joins this list; one
    /// declared childless is `SettingsCatalogDrawerTests`'.
    private var filledDrawers:
        [(
            SettingsDestination, SettingsContainer,
            any AnySettingsDrawer, [String]
        )]
    {
        [
            (
                .general, .advanced,
                SettingsCatalog.general.generalAdvanced,
                ["General", "Advanced"]
            ),
            (
                .bars, .spaceBar,
                SettingsCatalog.bars.spaceBarStyle,
                ["Bars", "Style"]
            ),
            (
                .bars, .appBar,
                SettingsCatalog.bars.appBarStyle,
                ["Bars", "Style"]
            ),
        ]
    }

    private func showMoreRows(
        in destination: SettingsDestination,
        _ container: SettingsContainer
    ) -> [SettingKey] {
        SettingKey.allCases.filter {
            $0.placement.area == destination.area
                && $0.placement.container == container
                && $0.placement.tier == .showMore
                && SettingsSearchIndex.indexes($0)
        }
    }

    /// The #1250 defect, held for every filled drawer: a
    /// disclosure is collapsed by default, and a census hit
    /// inside it used to land on the destination root, drawer
    /// shut, row unrendered. Every indexed `.showMore` row the
    /// census places in the drawer's container carries a
    /// catalog anchor the drawer EXPANDS for, and its breadcrumb
    /// names the drawer.
    @Test("a hit inside a filled drawer opens it")
    func drawerHitsOpenTheirDrawer() {
        pinEnglish()
        defer { reset() }
        let rows = SettingsSearchIndex.rows()
        for (destination, container, drawer, path) in filledDrawers {
            let hidden = showMoreRows(in: destination, container)
            // Non-vacuity only — each membership is its own
            // census-render suite's, never a count pinned here.
            #expect(!hidden.isEmpty, Comment(rawValue: "\(container)"))
            for key in hidden {
                let row = rows.first { $0.key == key }
                let anchor = row?.anchor.anchor
                #expect(anchor != nil, Comment(rawValue: key.id))
                #expect(
                    drawer.shouldExpand(revealing: anchor),
                    Comment(rawValue: key.id)
                )
                #expect(
                    row?.path == path,
                    Comment(rawValue: key.id)
                )
            }
        }
    }

    /// Gaps & Borders' `.showMore` rows sit at REST in their
    /// cards (no drawer draws them), so an anchor there buys the
    /// scroll and the wash rather than an expansion — the hit
    /// still lands on the row, breadcrumb the destination alone.
    /// Read with the bridge present so the sticky reach row is
    /// indexed. The drag ghost / drop zone `Border` and `Fill`
    /// rows are the stated residue: two census rows share one
    /// label key per column, and the label-key join cannot tell
    /// them apart, so they stay anchor-less by ruling rather than
    /// resolving onto the first column declared.
    @Test("a Gaps & Borders row lands on its own control")
    func gapsAndBordersRowsCarryAnchors() {
        pinEnglish()
        defer { reset() }
        let before = SettingsSearchIndex.canDriveDesktops
        defer { SettingsSearchIndex.canDriveDesktops = before }
        SettingsSearchIndex.canDriveDesktops = true
        let rows = SettingsSearchIndex.rows()
        for container in [
            SettingsContainer.focusBorder, .stickyWindows,
        ] {
            let hidden = showMoreRows(in: .gapsAndBorders, container)
            #expect(!hidden.isEmpty, Comment(rawValue: "\(container)"))
            for key in hidden {
                let row = rows.first { $0.key == key }
                #expect(
                    row?.anchor.anchor != nil,
                    Comment(rawValue: key.id)
                )
                #expect(
                    row?.path == ["Gaps & Borders"],
                    Comment(rawValue: key.id)
                )
            }
        }
        let drag = showMoreRows(in: .gapsAndBorders, .dragAndDrop)
        #expect(drag.count == 4)
        for key in drag {
            let row = rows.first { $0.key == key }
            #expect(
                row?.anchor.anchor == nil,
                Comment(rawValue: key.id)
            )
        }
    }

    /// The two bars' Style drawers share one label key and are
    /// told apart by instance; their rows carry the bar's OWN
    /// keys, so the join lands each census row on its own bar's
    /// child rather than the first drawer declared. Pinned on
    /// the one row both bars have under the same English.
    @Test("a bar's row lands on its own bar's drawer")
    func barRowsLandOnTheirOwnBar() {
        pinEnglish()
        defer { reset() }
        let rows = SettingsSearchIndex.rows()
        let space = rows.first {
            $0.key == .spaceBar(.spaceBarFontSize)
        }
        let app = rows.first { $0.key == .appBar(.appBarFontSize) }
        #expect(space?.anchor.anchor == "space_bar.font_size")
        #expect(app?.anchor.anchor == "app_bar.font_size")
        #expect(
            SettingsCatalog.bars.spaceBarStyle.shouldExpand(
                revealing: space?.anchor.anchor
            )
        )
        #expect(
            !SettingsCatalog.bars.appBarStyle.shouldExpand(
                revealing: space?.anchor.anchor
            )
        )
    }
}
