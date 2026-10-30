import KiwiDeskCore
import SwiftUI

/// Drag & drop card: whether each drag marker shows (#231, #2797).
/// The markers' look is fixed, so the card holds their two
/// switches alone; the panel preview draws them.
struct DragVisualsEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.gapsAndBorders.dragCard,
            caption: L(
                "drag.caption",
                "Drag a window onto another to swap "
                    + "their positions in the layout."
            )
        ) {
            ToggleRow(
                label: L("drag.drop_zone.show", "Show drop zone"),
                isOn: $model.config.settings.dragDropZone.enabled
            )
            ToggleRow(
                label: L(
                    "drag.ghost.show",
                    "Mark where the window came from"
                ),
                isOn: $model.config.settings.dragGhost.enabled
            )
        }
    }
}
