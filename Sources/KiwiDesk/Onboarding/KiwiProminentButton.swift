import SwiftUI

/// Primary button style with accent fill and `accentInk` for contrast (#828).
///
/// Every state is an opaque FILL token with the ink held
/// constant — never an opacity, which would composite against a
/// ground this style cannot know (#1198, gui.md).
struct KiwiProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration)
    }

    /// A real `View`: `@Environment` on a `ButtonStyle` is not
    /// an observation point, and `isEnabled` is load-bearing
    /// here (#1198).
    private struct Face: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration

        private var fill: Color {
            if !isEnabled { return SettingsTheme.accentDisabled }
            return configuration.isPressed
                ? SettingsTheme.accentPressed
                : SettingsTheme.accent
        }

        var body: some View {
            configuration.label
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(SettingsTheme.accentInk)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(
                        cornerRadius: SettingsTheme.chipRadius
                    )
                    .fill(fill)
                )
                // Accent ink stroke edge for definition on light
                // backgrounds.
                .overlay(
                    RoundedRectangle(
                        cornerRadius: SettingsTheme.chipRadius
                    )
                    .stroke(
                        SettingsTheme.accentInk.opacity(0.22),
                        lineWidth: 1
                    )
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: SettingsTheme.chipRadius
                    )
                )
        }
    }
}

extension View {
    /// Applies `KiwiProminentButtonStyle` to a view.
    func kiwiProminentButton() -> some View {
        buttonStyle(KiwiProminentButtonStyle())
    }
}
