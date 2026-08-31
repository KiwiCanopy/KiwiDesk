import SwiftUI

extension View {
    /// Paints a bordered button's LABEL in ordinary ink instead
    /// of the accent (#678 turn 16b tinted every bordered button
    /// green). The accent belongs on control FILLS, never on text.
    /// Not for every button: a `.destructive` label's system red
    /// IS the warning; `.borderedProminent` is a filled control;
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
