import SwiftUI

/// An icon picker grid cell: the chip's resting fill with no edge —
/// a picker tile, not a chip — sized to the grid column it is placed
/// in rather than padded past it, the press step on a press and the
/// chosen icon's accent mark on a layer of its own above it (#1173).
/// No hover lift until this popover's hover tracks the pointer
/// (#2440). No animation.
struct IconCellStyle: ButtonStyle {
    let marked: Bool

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, marked: marked)
    }

    /// The pointer's fill — the chip ladder's rest and press steps.
    static func fill(pressed: Bool) -> Color {
        ButtonChipStyle.fill(pressed: pressed, hovered: false)
    }

    /// The marking's layer, over the press — the chip ladder's.
    static func markFill(_ marked: Bool) -> Color {
        ButtonChipStyle.markFill(marked)
    }

    static let radius: CGFloat = 6

    private struct Face: View {
        let configuration: Configuration
        let marked: Bool

        var body: some View {
            configuration.label
                .foregroundStyle(SettingsTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background {
                    ZStack {
                        shape.fill(
                            IconCellStyle.fill(
                                pressed: configuration.isPressed
                            )
                        )
                        shape.fill(IconCellStyle.markFill(marked))
                    }
                }
                .contentShape([.interaction, .focusEffect], shape)
        }

        private var shape: RoundedRectangle {
            RoundedRectangle(
                cornerRadius: IconCellStyle.radius,
                style: .continuous
            )
        }
    }
}
