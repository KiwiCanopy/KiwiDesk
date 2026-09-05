import SwiftUI

/// Primary button style with accent fill and `accentInk` for contrast (#828).
///
/// Every state is a FILL swap with the ink held constant, never
/// an opacity over the ground: a translucent state composites
/// against whatever the button sits on, so the same modifier
/// pressed darker on the tour's card and lighter on the save
/// pill, and drained the label it exists to keep readable
/// (#1198). An opaque fill is what lets the style promise a
/// ratio it can actually measure — the label's ground is its
/// own fill, on any plate.
struct KiwiProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration)
    }

    /// A real `View`, because `@Environment` on a `ButtonStyle`
    /// is not a supported observation point — and since #1198
    /// the disabled state is the only one that drains the
    /// accent, so a stale read would draw an available button
    /// that refuses every click.
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
