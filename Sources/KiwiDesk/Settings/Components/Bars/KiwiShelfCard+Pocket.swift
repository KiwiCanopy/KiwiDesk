import KiwiDeskCore
import SwiftUI

/// The pocket's place on KiwiShelf's card (#2678, 2026-10-29
/// ruling): a section at a bar edge's nearer end, or a handle on an
/// edge no bar shows.
extension KiwiShelfCard {
    var pocketEdgeRow: some View {
        SegmentedPicker(
            SettingsCatalog.bars.kiwishelfPocketEdge.text,
            selection: shelf.pocketEdge,
            options: AppBarOptions.edge.map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.pocket_edge.help",
                "The screen edge the Pocket sits on."
            )
        )
        .searchAnchored(SettingsCatalog.bars.kiwishelfPocketEdge)
    }

    var pocketPositionRow: some View {
        let label = SettingsCatalog.bars.kiwishelfPocketPosition.text
        let readout = SettingsValueReadout.percent(
            Double(shelf.wrappedValue.pocketPosition) / 100
        )
        return SettingsRowShape {
            SettingsRowLabel(
                label: label,
                help: L(
                    "kiwishelf.pocket_position.help",
                    "On a bar's edge, the Pocket takes the nearer end."
                )
            )
        } control: {
            HStack(spacing: 6) {
                SettingsSlider(
                    value: Binding(
                        get: { Double(shelf.wrappedValue.pocketPosition) },
                        set: {
                            shelf.wrappedValue.pocketPosition =
                                KiwiShelf.clampPocketPosition(CGFloat($0))
                        }
                    ),
                    range: 0...100,
                    step: 1,
                    label: label,
                    spokenValue: PocketGroup.spokenPosition(
                        readout,
                        edge: shelf.wrappedValue.pocketEdge
                    ),
                    ends: PocketGroup.ends(shelf.wrappedValue.pocketEdge)
                )
                Text(readout)
                    .monospacedDigit()
                    .accessibilityHidden(true)
            }
        }
        .searchAnchored(SettingsCatalog.bars.kiwishelfPocketPosition)
    }
}
