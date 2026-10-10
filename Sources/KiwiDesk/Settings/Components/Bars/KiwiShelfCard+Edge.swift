import KiwiDeskCore
import SwiftUI

/// Position (#1731): the master writes both bars' edges; the Each
/// bar drawer holds one per bar and opens by itself while they
/// differ, when the master selects nothing and says why through
/// its `?` (`GapsBordersGates.followersDiffer`).
extension KiwiShelfCard {
    var edgesSplit: Bool {
        GapsBordersGates(settings: model.config.settings)
            .followersDiffer(for: .kiwishelf(.edge))
    }

    var edgeMasterHelp: String {
        edgesSplit
            ? BarsGateHelp.edgesDiffer
            : L(
                "kiwishelf.edge.label.help",
                "Which screen edge the bars sit on. Put each on its "
                    + "own edge under \u{201C}%1$@\u{201D}.",
                L("kiwishelf.each_bar", "Each bar")
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
            SettingsCatalog.bars.kiwishelfEdges,
            isExpanded: $edgesExpanded,
            scrollHoisted: true,
            locked: edgesSplit
        ) {
            // Spelled out in `BarsRowOrder.kiwishelfEdges`' order:
            // `row(for:)` renders this very row, and an opaque
            // type cannot contain itself.
            VStack(alignment: .leading, spacing: 10) {
                spaceBarEdgeRow
                // Hidden, never greyed, on one screen (#1948).
                if model.offersScreenEdges(\.spaceBarStyle) {
                    ScreenEdgesDrawer(
                        model: model,
                        bar: \.spaceBarStyle,
                        title: L(
                            "kiwishelf.edge.per_screen.space_bar",
                            "Per screen"
                        ),
                        barName: L("kiwishelf.edge.space_bar", "Space Bar"),
                        options: edgeOptions
                    )
                    .searchAnchored(
                        SettingsCatalog.bars.kiwishelfEdges.children
                            .kiwishelfSpaceBarScreenEdges
                    )
                }
                appBarEdgeRow
                if model.offersScreenEdges(\.appBarStyle) {
                    ScreenEdgesDrawer(
                        model: model,
                        bar: \.appBarStyle,
                        title: L(
                            "kiwishelf.edge.per_screen.app_bar",
                            "Per screen"
                        ),
                        barName: L("kiwishelf.edge.app_bar", "App Bar"),
                        options: edgeOptions
                    )
                    .searchAnchored(
                        SettingsCatalog.bars.kiwishelfEdges.children
                            .kiwishelfAppBarScreenEdges
                    )
                }
            }
            .padding(.top, 8)
        }
        // Closes the drawer like Gaps' per-edge and per-axis ones.
        Divider()
    }

    var spaceBarEdgeRow: some View {
        SegmentedPicker(
            L("kiwishelf.edge.space_bar", "Space Bar"),
            selection: model.barEdge(\.spaceBarStyle),
            options: edgeOptions,
            help: screensDifferHelp(\.spaceBarStyle, appBar: false)
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEdges.children
                .kiwishelfSpaceBarEdge
        )
    }

    var appBarEdgeRow: some View {
        SegmentedPicker(
            L("kiwishelf.edge.app_bar", "App Bar"),
            selection: model.barEdge(\.appBarStyle),
            options: edgeOptions,
            help: screensDifferHelp(\.appBarStyle, appBar: true)
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEdges.children
                .kiwishelfAppBarEdge
        )
    }

    /// The `?` a bar row shows while its screens differ (#1948).
    private func screensDifferHelp<Bar: ScreenEdged>(
        _ bar: KeyPath<TilingSettings, Bar>,
        appBar: Bool
    ) -> String? {
        guard model.config.settings[keyPath: bar].screensDiffer
        else { return nil }
        return BarsGateHelp.screensDiffer(appBar: appBar)
    }

    private var edgeOptions: [(String, AppBarEdge)] {
        AppBarOptions.edge.map { ($0.1, $0.0) }
    }
}
