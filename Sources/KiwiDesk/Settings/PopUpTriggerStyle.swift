import SwiftUI

/// The face of a button that opens a pop-up of its own — the Font
/// and app pickers' triggers — drawn as the native pop-up menu
/// beside it reads (owner ruling 2026-10-17): a capsule on the
/// button-chip fill ladder, lifting under the pointer as a custom
/// hit area does (ui-patterns.md), no edge. Reached only through
/// `settingsPopUpTrigger()`, which pairs the neutral label.
struct PopUpTriggerStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration)
    }

    private struct Face: View {
        let configuration: Configuration
        @State private var hovered = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.controlSize) private var controlSize
        @Environment(\.font) private var font

        var body: some View {
            let metrics = ButtonChipStyle.metrics(for: controlSize)
            configuration.label
                .font(font ?? .system(size: metrics.font))
                .lineLimit(1)
                .foregroundStyle(
                    isEnabled ? SettingsTheme.ink : SettingsTheme.ink3
                )
                .padding(.horizontal, metrics.horizontal)
                .padding(.vertical, metrics.vertical)
                .background {
                    Capsule().fill(
                        ButtonChipStyle.fill(
                            pressed: isEnabled && configuration.isPressed,
                            hovered: isEnabled && hovered
                        )
                    )
                }
                .contentShape([.interaction, .focusEffect], Capsule())
                .onHover { hovered = $0 }
        }
    }
}
