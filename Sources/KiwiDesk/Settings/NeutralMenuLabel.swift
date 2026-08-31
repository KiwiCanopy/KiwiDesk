import SwiftUI

extension View {
    /// Paints a borderless menu's LABEL in ordinary ink instead
    /// of the accent (#678 turn 16b tinted the window kiwi and
    /// every such menu became green text on green chips). The
    /// accent belongs on control FILLS, never on text naming the
    /// current value. BOTH `.tint` and `.foregroundStyle`: an
    /// AppKit-backed control's label follows the tint, which
    /// `foregroundStyle` alone does not reach. Every
    /// `.menuStyle(.borderlessButton)` in the Settings tree must
    /// carry this (`SettingsLabelNeutralityTests`).
    func neutralMenuLabel() -> some View {
        tint(SettingsTheme.ink)
            .foregroundStyle(SettingsTheme.ink)
    }
}
