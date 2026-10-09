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

    var edgesDisclosure: Binding<Bool> {
        Binding(
            get: { edgesExpanded || edgesSplit },
            set: { edgesExpanded = $0 }
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
            isExpanded: edgesDisclosure,
            scrollHoisted: true
        ) {
            // Spelled out in `BarsRowOrder.kiwishelfEdges`' order:
            // `row(for:)` renders this very row, and an opaque
            // type cannot contain itself.
            VStack(alignment: .leading, spacing: 10) {
                spaceBarEdgeRow
                appBarEdgeRow
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
            options: edgeOptions
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
            options: edgeOptions
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEdges.children
                .kiwishelfAppBarEdge
        )
    }

    private var edgeOptions: [(String, AppBarEdge)] {
        AppBarOptions.edge.map { ($0.1, $0.0) }
    }
}
