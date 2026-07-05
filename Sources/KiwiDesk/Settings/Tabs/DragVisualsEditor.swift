import KiwiDeskCore
import SwiftUI

/// Drag-and-drop visuals: the dragged window's ghost slot, the
/// swap target's drop zone, and their shared corner radius
/// (05_GUI_Concept §2, Tab 3).
struct DragVisualsEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection("Ghost (dragged window)") {
                DragVisualControls(
                    visual: $model.config.settings.dragGhost
                )
            }
            SettingsSection("Drop zone (swap target)") {
                DragVisualControls(
                    visual: $model.config.settings.dragDropZone
                )
            }
            SettingsSection("Corner radius") {
                PtSlider(
                    label: "Radius",
                    value: $model.config.settings
                        .dragCornerRadius,
                    range: 0...40
                )
            }
        }
    }
}

/// The border + fill controls shared by ghost and drop zone.
struct DragVisualControls: View {
    @Binding var visual: DragVisual

    var body: some View {
        Toggle("Enabled", isOn: $visual.enabled)
        Divider()
        Toggle("Border", isOn: $visual.border)
        HexColorField(
            label: "Border color",
            hex: $visual.borderColor
        )
        PtSlider(
            label: "Border width",
            value: $visual.borderThickness,
            range: 0...20
        )
        Picker(
            "Border alignment",
            selection: $visual.borderAlignment
        ) {
            Text("Inside").tag(BorderAlignment.inside)
            Text("Outside").tag(BorderAlignment.outside)
        }
        Divider()
        Toggle("Fill", isOn: $visual.fill)
        HexColorField(
            label: "Fill color",
            hex: $visual.fillColor
        )
    }
}
