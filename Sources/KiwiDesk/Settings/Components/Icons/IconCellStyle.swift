import SwiftUI

/// An icon picker grid cell: the chip's resting fill with no edge —
/// a picker tile, not a chip — sized to the grid column it is placed
/// in rather than padded past it, the chip ladder's hover and press
/// steps and the chosen icon's accent mark on a layer of its own
/// above them (#1173). No animation.
struct IconCellStyle: ButtonStyle {
    let marked: Bool

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, marked: marked)
    }

    /// The pointer's fill — the chip ladder's rest, hover and press
    /// steps.
    static func fill(pressed: Bool, hovered: Bool) -> Color {
        ButtonChipStyle.fill(pressed: pressed, hovered: hovered)
    }

    /// The marking's layer, over the press — the chip ladder's.
    static func markFill(_ marked: Bool) -> Color {
        ButtonChipStyle.markFill(marked)
    }

    static let radius: CGFloat = 6

    private struct Face: View {
        let configuration: Configuration
        let marked: Bool
        @State private var hovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(SettingsTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background {
                    ZStack {
                        shape.fill(
                            IconCellStyle.fill(
                                pressed: configuration.isPressed,
                                hovered: hovered
                            )
                        )
                        shape.fill(IconCellStyle.markFill(marked))
                    }
                }
                .contentShape([.interaction, .focusEffect], shape)
                .onHover { hovered = $0 }
        }

        private var shape: RoundedRectangle {
            RoundedRectangle(
                cornerRadius: IconCellStyle.radius,
                style: .continuous
            )
        }
    }
}
