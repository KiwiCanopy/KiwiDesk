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
                L("drag.title", "Drag & Drop"),
                caption: L(
                    "drag.caption",
                    "Drag a window onto another to swap "
                        + "their positions in the layout."
                )
            ) {
                previewStrip
                PtSlider(
                    label: L("drag.corner_radius", "Corner radius"),
                    value: $model.config.settings
                        .dragCornerRadius,
                    range: 0...40
                )
            }
            SettingsSection(
                ghostLabel,
                caption: L(
                    "drag.ghost.caption",
                    "Marks the position your window is "
                        + "dragged from."
                ),
                subsection: true
            ) {
                DragVisualControls(
                    visual: $model.config.settings.dragGhost
                )
            }
            SettingsSection(
                dropZoneLabel,
                caption: L(
                    "drag.drop_zone.caption",
                    "Marks the position your window will "
                        + "snap into when dropped."
                ),
                subsection: true
            ) {
                DragVisualControls(
                    visual: $model.config.settings
                        .dragDropZone
                )
            }
        }
    }

    private var ghostLabel: String { L("drag.ghost", "Ghost") }
    private var dropZoneLabel: String {
        L("drag.drop_zone", "Drop zone")
    }

    private var previewStrip: some View {
        HStack(spacing: 16) {
            DragVisualPreview(
                label: ghostLabel,
                visual: model.config.settings.dragGhost,
                cornerRadius: model.config.settings
                    .dragCornerRadius
            )
            DragVisualPreview(
                label: dropZoneLabel,
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
                    Text(L("drag.disabled", "disabled"))
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
            .fill(
                visual.fill
                    ? Color(kiwiHex: visual.fillColor) : .clear
            )
            .overlay {
                if visual.border {
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(
                            Color(kiwiHex: visual.borderColor),
                            lineWidth: min(
                                visual.borderThickness,
                                10
                            )
                        )
                }
            }
            .opacity(visual.enabled ? 1 : 0.25)
    }
}

/// The border + fill controls shared by ghost and drop zone.
struct DragVisualControls: View {
    @Binding var visual: DragVisual

    var body: some View {
        Toggle(L("drag.enabled", "Enabled"), isOn: $visual.enabled)
        Divider()
        Toggle(L("drag.border", "Border"), isOn: $visual.border)
        HexColorField(
            label: L("drag.border_color", "Border color"),
            hex: $visual.borderColor
        )
        PtSlider(
            label: L("drag.border_width", "Border width"),
            value: $visual.borderThickness,
            range: 0...20
        )
        DropdownRow(label: borderAlignmentLabel) {
            Picker(
                borderAlignmentLabel,
                selection: $visual.borderAlignment
            ) {
                Text(L("drag.inside", "Inside"))
                    .tag(BorderAlignment.inside)
                Text(L("drag.outside", "Outside"))
                    .tag(BorderAlignment.outside)
            }
        }
        Divider()
        Toggle(L("drag.fill", "Fill"), isOn: $visual.fill)
        HexColorField(
            label: L("drag.fill_color", "Fill color"),
            hex: $visual.fillColor
        )
    }

    private var borderAlignmentLabel: String {
        L("drag.border_alignment", "Border alignment")
    }
}
