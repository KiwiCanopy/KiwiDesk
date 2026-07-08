import KiwiDeskCore
import SwiftUI

/// Drag-and-drop visuals (#68 §3.14): a live preview strip so
/// color/width/alignment edits are judged without starting an
/// actual drag, the shared corner radius beside it (it styles
/// both visuals), and the Ghost / Drop-zone control sets — two
/// sections on purpose: they style two genuinely distinct
/// runtime visuals users routinely want different.
struct DragVisualsEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(
                "Drag & Drop",
                caption: "Drag a window onto another to swap "
                    + "their positions in the layout."
            ) {
                previewStrip
                PtSlider(
                    label: "Corner radius",
                    value: $model.config.settings
                        .dragCornerRadius,
                    range: 0...40
                )
            }
            SettingsSection(
                "Ghost",
                caption: "Marks the position your window is "
                    + "dragged from.",
                subsection: true
            ) {
                DragVisualControls(
                    visual: $model.config.settings.dragGhost
                )
            }
            SettingsSection(
                "Drop zone",
                caption: "Marks the position your window will "
                    + "snap into when dropped.",
                subsection: true
            ) {
                DragVisualControls(
                    visual: $model.config.settings
                        .dragDropZone
                )
            }
        }
    }

    private var previewStrip: some View {
        HStack(spacing: 16) {
            DragVisualPreview(
                label: "Ghost",
                visual: model.config.settings.dragGhost,
                cornerRadius: model.config.settings
                    .dragCornerRadius
            )
            DragVisualPreview(
                label: "Drop zone",
                visual: model.config.settings.dragDropZone,
                cornerRadius: model.config.settings
                    .dragCornerRadius
            )
        }
        .frame(maxWidth: .infinity)
    }
}

/// One mock window rect rendered with the current visual's
/// fill, border, and the shared corner radius.
private struct DragVisualPreview: View {
    let label: String
    let visual: DragVisual
    let cornerRadius: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // A neutral desktop backdrop so translucent
                // fills read realistically.
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
                mock
                    .padding(10)
                if !visual.enabled {
                    Text("disabled")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 84)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var mock: some View {
        let radius = min(cornerRadius, 20)
        return RoundedRectangle(cornerRadius: radius)
            .fill(visual.fill ? color(visual.fillColor) : .clear)
            .overlay {
                if visual.border {
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(
                            color(visual.borderColor),
                            lineWidth: min(
                                visual.borderThickness,
                                10
                            )
                        )
                }
            }
            .opacity(visual.enabled ? 1 : 0.25)
    }

    private func color(_ hex: String) -> Color {
        guard let rgba = DragVisual.parseHex(hex) else {
            return .clear
        }
        return Color(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
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
