import KiwiDeskCore
import SwiftUI

/// Position (#1731): the master writes both bars' edges and the
/// Pocket's (#3376), and Each bar and Pocket hangs under it
/// (`eachDrawer`, #3612). A master selects nothing while what it
/// sets differs and says why through its `?`
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
        eachDrawer
    }

    var spaceBarEdgeRow: some View {
        SegmentedPicker(
            L("kiwishelf.edge.label", "Position"),
            spokenLabel: ShelfBlock.spaceBar.spoken(
                L("kiwishelf.edge.label", "Position")
            ),
            selection: model.barEdge(\.spaceBarStyle),
            options: edgeOptions,
            help: screensDifferHelp(
                \.spaceBarStyle,
                BarsGateHelp.screensDiffer
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
            spokenLabel: ShelfBlock.appBar.spoken(
                L("kiwishelf.edge.label", "Position")
            ),
            selection: model.barEdge(\.appBarStyle),
            options: edgeOptions,
            help: screensDifferHelp(
                \.appBarStyle,
                BarsGateHelp.screensDiffer
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
            spokenLabel: ShelfBlock.pocket.spoken(
                L("kiwishelf.edge.label", "Position")
            ),
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

    var edgeOptions: [(String, AppBarEdge)] {
        AppBarOptions.edge.map { ($0.1, $0.0) }
    }
}
