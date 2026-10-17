import SwiftUI

/// The one face both chip seals draw: the label in the control
/// size's font and room, its ink and the fill ladder gated on
/// `isEnabled`, so a disabled button neither lifts nor presses.
/// The action chip (`ButtonChipStyle`) is the bezel's rounded
/// rectangle under `chipEdge`; a pop-up trigger
/// (`PopUpTriggerStyle`) is a capsule with no edge (owner ruling
/// 2026-10-17). A real `View`, so the hover is state it can hold.
struct ChipFace: View {
    let configuration: ButtonStyleConfiguration
    let popUp: Bool
    @State private var hovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize
    @Environment(\.font) private var font

    var body: some View {
        configuration.label
            // A caller's font wins, as it did on the bezel.
            .font(font ?? .system(size: metrics.font))
            .lineLimit(1)
            .foregroundStyle(
                isEnabled ? SettingsTheme.ink : SettingsTheme.ink3
            )
            .padding(.horizontal, metrics.horizontal)
            .padding(.vertical, metrics.vertical)
            .background {
                shape.fill(
                    ButtonChipStyle.fill(
                        pressed: isEnabled && configuration.isPressed,
                        hovered: isEnabled && hovered
                    )
                )
            }
            .overlay {
                if !popUp {
                    bezel.strokeBorder(SettingsTheme.chipEdge, lineWidth: 1)
                }
            }
            .contentShape([.interaction, .focusEffect], shape)
            .onHover { hovered = $0 }
    }

    private var shape: AnyShape {
        popUp ? AnyShape(Capsule()) : AnyShape(bezel)
    }

    /// The action chip keeps the system bezel's rounded rectangle,
    /// never a capsule (owner, 2026-10-17).
    private var bezel: RoundedRectangle {
        RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
    }

    private var metrics: ButtonChipStyle.Metrics {
        ButtonChipStyle.metrics(for: controlSize)
    }
}
