import SwiftUI

/// Primary button style with accent fill and `accentInk` for contrast (#828).
struct KiwiProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(SettingsTheme.accentInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.chipRadius
                )
                .fill(SettingsTheme.accent)
            )
            // Accent ink stroke edge for definition on light backgrounds.
            .overlay(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.chipRadius
                )
                .stroke(
                    SettingsTheme.accentInk.opacity(0.22),
                    lineWidth: 1
                )
            )
            // Opacity applies to entire button to maintain ink contrast.
            .opacity(pressedOrDisabled(configuration) ? 0.72 : 1)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.chipRadius
                )
            )
    }

    private func pressedOrDisabled(
        _ configuration: Configuration
    ) -> Bool {
        configuration.isPressed || !isEnabled
    }
}

extension View {
    /// Applies `KiwiProminentButtonStyle` to a view.
    func kiwiProminentButton() -> some View {
        buttonStyle(KiwiProminentButtonStyle())
    }
}
