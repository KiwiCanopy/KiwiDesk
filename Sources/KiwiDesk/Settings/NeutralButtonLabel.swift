import SwiftUI

extension View {
    /// Paints a bordered button's LABEL in ordinary ink instead
    /// of the accent (#678 turn 16b tinted every bordered button
    /// green). The accent belongs on control FILLS, never on text.
    /// Never hand-paired on a raw `.destructive` button, whose red
    /// IS the warning: a destructive action goes through the seal,
    /// whose chip face draws its label red (#3630).
    /// `.borderedProminent` is a filled control;
    /// per-state tinters are exempt via `SettingsBorderedSealTests`'
    /// `borderedExempt` map. BOTH `.tint` and `.foregroundStyle`,
    /// so the AppKit-drawn half of a label is covered too.
    /// Bordered actions route through `settingsActionButton()`
    /// (#771); `SettingsLabelNeutralityTests` enumerates direct
    /// uses (`SettingsTheme.ink`, `neutralMenuLabel()`).
    func neutralButtonLabel() -> some View {
        tint(SettingsTheme.ink)
            .foregroundStyle(SettingsTheme.ink)
    }
}
