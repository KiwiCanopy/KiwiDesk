import KiwiDeskCore
import SwiftUI

/// The one width and corner style every window stroke takes —
/// the focus ring, the drag ghost and the drop zone (#754, #1742).
struct BordersCard: View {
    @ObservedObject var model: SettingsModel

    private var caption: String {
        L(
            "border.shared.caption",
            "%1$@ sets the focus ring; %2$@ also shape the drag "
                + "ghost and the drop zone.",
            L("border.width", "Width"),
            L("border.corner_style", "Corners")
        )
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.gapsAndBorders.bordersCard,
            caption: caption
        ) {
            rows
        }
    }

    @ViewBuilder private var rows: some View {
        PtSlider(
            label: L("border.width", "Width"),
            value: $model.config.settings.borderStyle.width,
            range: 1...20
        )
        SegmentedPicker(
            L("border.corner_style", "Corners"),
            selection: $model.config.settings.borderStyle.cornerStyle,
            options: [
                (
                    L("border.corner.rounded", "Rounded"),
                    BorderStyle.CornerStyle.rounded
                ),
                (
                    L("border.corner.square", "Square"),
                    BorderStyle.CornerStyle.square
                ),
            ]
        )
    }
}
