import KiwiDeskCore
import SwiftUI

/// Position (#1731) and Each bar and Pocket under it, grouped by
/// bar (#3612): the master writes both bars' edges and the Pocket's
/// (#3376); the drawer holds each bar's Show, Position and Per
/// screen or area drawer, and opens by itself while they differ,
/// when a master selects nothing and says why through its `?`
/// (`GapsBordersGates.followersDiffer`).
extension KiwiShelfCard {
    var edgesSplit: Bool {
        GapsBordersGates(settings: model.config.settings)
            .followersDiffer(for: .kiwishelf(.edge))
    }

    /// Whether Each bar and Pocket is held open: the bars' Show or
    /// edges differ, or a screen or area shows a bar its own way,
    /// which its Per screen or area rows draw (#3517).
    var eachHeldOpen: Bool {
        visibilitySplit || edgesSplit || model.hasScreenShows(.space)
            || model.hasScreenShows(.app)
    }

    var edgeMasterHelp: String {
        edgesSplit
            ? BarsGateHelp.edgesDiffer
            : L(
                "kiwishelf.edge.label.help",
                "Which screen edge the bars and the Pocket sit on. "
                    + "Put each on its own edge under "
                    + "\u{201C}%1$@\u{201D}.",
                L("kiwishelf.show.each_bar", "Each bar and Pocket")
            )
    }

    @ViewBuilder var edgeRows: some View {
        SegmentedPicker(
            L("kiwishelf.edge.label", "Position"),
            selection: model.barEdgeMaster,
            options: edgeOptions,
            help: edgeMasterHelp
        )
        SettingsDisclosure(
            SettingsCatalog.bars.kiwishelfEach,
            chrome: .attached,
            isExpanded: $eachExpanded,
            scrollHoisted: true,
            locked: eachHeldOpen
        ) {
            // Spelled out in `BarsRowOrder.kiwishelfEach`' order:
            // `row(for:)` renders this very row, and an opaque
            // type cannot contain itself.
            VStack(alignment: .leading, spacing: 16) {
                spaceBarBlock
                appBarBlock
                pocketBlock
            }
            .padding(.top, 8)
        }
    }

    private var spaceBarBlock: some View {
        barGroup(L("kiwishelf.edge.space_bar", "Space Bar")) {
            showRow(.spaceBar(.spaceBarVisibility))
            spaceBarEdgeRow
            // The Show rows anchor apart from the edges, so a hit on
            // either lands on this drawer (#3517).
            VStack(alignment: .leading, spacing: 0) {
                ScreenEdgesDrawer(
                    model: model,
                    bar: \.spaceBarStyle,
                    title: L(
                        "kiwishelf.edge.per_screen.space_bar",
                        "Per screen or area"
                    ),
                    barName: L("kiwishelf.edge.space_bar", "Space Bar"),
                    options: edgeOptions,
                    show: .space
                )
                .searchAnchored(
                    SettingsCatalog.bars.kiwishelfEach.children
                        .kiwishelfSpaceBarScreenEdges
                )
            }
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfEach.children
                    .kiwishelfSpaceBarScreenShows
            )
        }
    }

    private var appBarBlock: some View {
        barGroup(L("kiwishelf.edge.app_bar", "App Bar")) {
            showRow(.layoutAppBar(.monocleAppBarVisibility))
            showRow(.layoutAppBar(.scrollingAppBarVisibility))
            appBarEdgeRow
            VStack(alignment: .leading, spacing: 0) {
                ScreenEdgesDrawer(
                    model: model,
                    bar: \.appBarStyle,
                    title: L(
                        "kiwishelf.edge.per_screen.app_bar",
                        "Per screen or area"
                    ),
                    barName: L("kiwishelf.edge.app_bar", "App Bar"),
                    options: edgeOptions,
                    show: .app
                )
                .searchAnchored(
                    SettingsCatalog.bars.kiwishelfEach.children
                        .kiwishelfAppBarScreenEdges
                )
            }
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfEach.children
                    .kiwishelfAppBarScreenShows
            )
        }
    }

    private var pocketBlock: some View {
        barGroup(L("kiwishelf.edge.pocket", "Pocket")) {
            showRow(.kiwishelf(.pocketVisibility))
            showRow(.kiwishelf(.pocketDragReveal))
            pocketEdgeRow
            // Edges alone: the Pocket has no Show per screen.
            ScreenEdgesDrawer(
                model: model,
                bar: \.kiwishelf.pocketEdges,
                title: L(
                    "kiwishelf.edge.per_screen.pocket",
                    "Per screen or area"
                ),
                barName: L("kiwishelf.edge.pocket", "Pocket"),
                options: edgeOptions
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfEach.children
                    .kiwishelfPocketScreenEdges
            )
            pocketPositionRows
        }
    }

    /// One bar's block in Each bar and Pocket: its name as a
    /// heading, then its rows.
    private func barGroup<Rows: View>(
        _ name: String,
        @ViewBuilder _ rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.body.weight(.semibold))
                .foregroundStyle(SettingsTheme.ink)
                .accessibilityAddTraits(.isHeader)
            rows()
        }
    }

    var spaceBarEdgeRow: some View {
        SegmentedPicker(
            L("kiwishelf.edge.label", "Position"),
            selection: model.barEdge(\.spaceBarStyle),
            options: edgeOptions,
            help: screensDifferHelp(
                \.spaceBarStyle,
                BarsGateHelp.screensDiffer(appBar: false)
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children
                .kiwishelfSpaceBarEdge
        )
    }

    var appBarEdgeRow: some View {
        SegmentedPicker(
            L("kiwishelf.edge.label", "Position"),
            selection: model.barEdge(\.appBarStyle),
            options: edgeOptions,
            help: screensDifferHelp(
                \.appBarStyle,
                BarsGateHelp.screensDiffer(appBar: true)
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children
                .kiwishelfAppBarEdge
        )
    }

    var pocketEdgeRow: some View {
        SegmentedPicker(
            L("kiwishelf.edge.label", "Position"),
            selection: model.barEdge(\.kiwishelf.pocketEdges),
            options: edgeOptions,
            help: screensDifferHelp(
                \.kiwishelf.pocketEdges,
                BarsGateHelp.pocketScreensDiffer
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children
                .kiwishelfPocketEdge
        )
    }

    /// The `?` an edge row shows while its screens differ (#1948,
    /// #3401): `sentence`, or none.
    private func screensDifferHelp<Bar: ScreenEdged>(
        _ bar: KeyPath<TilingSettings, Bar>,
        _ sentence: @autoclosure () -> String
    ) -> String? {
        guard model.config.settings[keyPath: bar].screensDiffer
        else { return nil }
        return sentence()
    }

    private var edgeOptions: [(String, AppBarEdge)] {
        AppBarOptions.edge.map { ($0.1, $0.0) }
    }
}
