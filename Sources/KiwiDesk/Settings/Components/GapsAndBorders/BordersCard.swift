import KiwiDeskCore
import SwiftUI

/// Shared border width and corner style settings card
/// (`GapsBordersGates`, #754).
struct BordersCard: View {
    @ObservedObject var model: SettingsModel

    private var gates: GapsBordersGates {
        GapsBordersGates(settings: model.config.settings)
    }

    private var caption: String {
        L(
            "border.shared.caption",
            "The focus ring, the drag ghost and the drop zone "
                + "are strokes KiwiDesk draws around a window."
        )
    }

    private var widthHelp: String? {
        gates.strokesDiffer(for: .borders(.borderWidthMaster))
            ? GapsBordersGateHelp.strokesDiffer : nil
    }

    private var cornersHelp: String? {
        gates.strokesDiffer(for: .borders(.borderCornerMaster))
            ? GapsBordersGateHelp.strokesDiffer : nil
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.gapsAndBorders.bordersCard,
            caption: caption
        ) {
            masters
        }
    }

    @ViewBuilder private var masters: some View {
        PtSlider(
            label: L("border.width", "Width"),
            value: model.borderWidthMaster,
            range: 1...20,
            help: widthHelp
        )
        SegmentedPicker(
            L("border.corner_style", "Corners"),
            selection: model.borderCornersMaster,
            options: [
                (
                    L("border.corner.rounded", "Rounded"),
                    BorderStyle.CornerStyle.rounded
                ),
                (
                    L("border.corner.square", "Square"),
                    BorderStyle.CornerStyle.square
                ),
            ],
            help: cornersHelp
        )
    }
}
