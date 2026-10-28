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
    /// KiwiHub's paint where a chip sits on its Fill (#2569): the
    /// look's inks and the shelf's hover; untinted, nothing.
    @Environment(\.kiwiHubPaint) private var paint

    var body: some View {
        configuration.label
            // A caller's font wins, as it did on the bezel.
            .font(font ?? .system(size: metrics.font))
            .lineLimit(1)
            .foregroundStyle(ink)
            .padding(.horizontal, metrics.horizontal)
            .padding(.vertical, metrics.vertical)
            .background {
                shape.fill(fill)
            }
            .overlay {
                if !popUp {
                    bezel.strokeBorder(SettingsTheme.chipEdge, lineWidth: 1)
                }
            }
            .contentShape([.interaction, .focusEffect], shape)
            .onHover { hovered = $0 }
    }

    private var lifted: Bool {
        isEnabled && (hovered || configuration.isPressed)
    }

    /// Untinted, the chip ladder; on KiwiHub's Fill a lifted chip
    /// takes the shelf's hover fill, a resting one the neutral rest,
    /// both fading along the Fill like its other fills (#2725).
    private var fill: AnyShapeStyle {
        if paint.tinted, lifted { return paint.fill(paint.rowHover) }
        return paint.fill(
            ButtonChipStyle.fill(
                pressed: isEnabled && configuration.isPressed,
                hovered: isEnabled && hovered
            )
        )
    }

    /// The theme's ink, or on KiwiHub's Fill the panel's own
    /// hierarchy and the shelf's hover ink (gui.md).
    private var ink: AnyShapeStyle {
        guard paint.tinted else {
            return AnyShapeStyle(
                isEnabled ? SettingsTheme.ink : SettingsTheme.ink3
            )
        }
        guard isEnabled else { return AnyShapeStyle(.tertiary) }
        if lifted, let hover = paint.hoverInk { return AnyShapeStyle(hover) }
        return AnyShapeStyle(.primary)
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
