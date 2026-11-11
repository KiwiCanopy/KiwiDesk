import SwiftUI

/// The Key sequences card's two container faces beside the plain
/// pop-up trigger (#3162 ▸ Ruling): dashed for a key running the
/// user's own Lua, tinted for a key that opens more keys. The pop-up
/// trigger's room and font, so a step's keys read one height.
struct SequenceContainerFace<Label: View>: View {
    enum Face {
        case dashed
        case tinted
    }

    let face: Face
    var pressed = false
    @ViewBuilder let label: Label

    @State private var hovered = false
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        let metrics = ButtonChipStyle.metrics(for: controlSize)
        label
            .font(.system(size: metrics.font))
            .lineLimit(1)
            .foregroundStyle(SettingsTheme.ink)
            .padding(.horizontal, metrics.horizontal)
            .padding(.vertical, metrics.vertical)
            .background {
                Capsule().fill(fill).overlay { edge }
            }
            .contentShape(Capsule())
            .onHover { hovered = $0 }
    }

    private var fill: AnyShapeStyle {
        switch face {
        case .tinted:
            let alpha = pressed ? 0.4 : hovered ? 0.3 : 0.2
            return AnyShapeStyle(SettingsTheme.accent.opacity(alpha))
        case .dashed:
            guard hovered || pressed else { return AnyShapeStyle(.clear) }
            return AnyShapeStyle(
                ButtonChipStyle.fill(pressed: pressed, hovered: hovered)
            )
        }
    }

    @ViewBuilder private var edge: some View {
        switch face {
        case .dashed:
            Capsule().strokeBorder(
                SettingsTheme.ink3,
                style: StrokeStyle(lineWidth: 1, dash: [3, 2])
            )
        case .tinted:
            Capsule().strokeBorder(SettingsTheme.accent, lineWidth: 1)
        }
    }
}

/// A button wearing the dashed face: a Lua key's description.
struct SequenceDashedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SequenceContainerFace(face: .dashed, pressed: configuration.isPressed)
        {
            configuration.label
        }
    }
}
