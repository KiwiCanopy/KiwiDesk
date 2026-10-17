import AppKit
import SwiftUI

/// The bordered action button's face (#2377): the button-chip tier
/// — `chipRest`, `chipHover` under the pointer, `chipPressed` while
/// pressed — under an edge no state moves, sized by the control
/// size the way the system bezel was. No animation; a disabled
/// button keeps its shape, drops its ink and stops reacting.
struct ButtonChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration)
    }

    /// The pointer's fill — the one ladder the jump chip shares.
    static func fill(pressed: Bool, hovered: Bool) -> Color {
        if pressed { return SettingsTheme.chipPressed }
        return hovered ? SettingsTheme.chipHover : SettingsTheme.chipRest
    }

    /// A real `View`, so the hover is state it can hold.
    private struct Face: View {
        let configuration: Configuration
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
                    shape.strokeBorder(
                        SettingsTheme.chipEdge,
                        lineWidth: 1
                    )
                }
                .contentShape([.interaction, .focusEffect], shape)
                .onHover { hovered = $0 }
        }

        /// The system bezel's rounded rectangle, not a capsule
        /// (owner, 2026-10-17).
        private var shape: RoundedRectangle {
            RoundedRectangle(
                cornerRadius: metrics.radius,
                style: .continuous
            )
        }

        /// The system font and the bezel's room per control size.
        private var metrics: Metrics {
            switch controlSize {
            case .mini:
                return Metrics(
                    font: 9,
                    horizontal: 6,
                    vertical: 2,
                    radius: 4
                )
            case .small:
                return Metrics(
                    font: 11,
                    horizontal: 8,
                    vertical: 3,
                    radius: 5
                )
            case .large, .extraLarge:
                return Metrics(
                    font: 13,
                    horizontal: 14,
                    vertical: 6,
                    radius: 8
                )
            default:
                return Metrics(
                    font: 13,
                    horizontal: 10,
                    vertical: 4,
                    radius: 6
                )
            }
        }
    }

    private struct Metrics {
        let font: CGFloat
        let horizontal: CGFloat
        let vertical: CGFloat
        let radius: CGFloat
    }
}
