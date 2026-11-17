import KiwiDeskCore
import SwiftUI

/// Position (#1731): the master writes both bars' edges and the
/// Pocket's (#3376); the Each bar and Pocket drawer holds one row
/// each and opens by itself while they differ, when the master
/// selects nothing and says why through its `?`
/// (`GapsBordersGates.followersDiffer`).
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
                "Which screen edge the bars and the Pocket sit on. "
                    + "Put each on its own edge under "
                    + "\u{201C}%1$@\u{201D}.",
                L("kiwishelf.edge.each", "Each bar and Pocket")
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
            chrome: .attached,
            isExpanded: $edgesExpanded,
            scrollHoisted: true,
            locked: edgesSplit
        ) {
            // Spelled out in `BarsRowOrder.kiwishelfEdges`' order:
            // `row(for:)` renders this very row, and an opaque
            // type cannot contain itself.
            VStack(alignment: .leading, spacing: 10) {
                spaceBarEdgeRow
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
                appBarEdgeRow
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
                pocketEdgeRow
                ScreenEdgesDrawer(
                    model: model,
                    bar: \.kiwishelf.pocketEdges,
                    title: L(
                        "kiwishelf.edge.per_screen.pocket",
                        "Per screen"
                    ),
                    barName: L("kiwishelf.edge.pocket", "Pocket"),
                    options: edgeOptions
                )
                .searchAnchored(
                    SettingsCatalog.bars.kiwishelfEdges.children
                        .kiwishelfPocketScreenEdges
                )
            }
            .padding(.top, 8)
        }
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

    var pocketEdgeRow: some View {
        SegmentedPicker(
            L("kiwishelf.edge.pocket", "Pocket"),
            selection: model.barEdge(\.kiwishelf.pocketEdges),
            options: edgeOptions,
            help: model.config.settings.kiwishelf.pocketEdges
                .screensDiffer ? BarsGateHelp.pocketScreensDiffer : nil
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEdges.children
                .kiwishelfPocketEdge
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
