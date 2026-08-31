import SwiftUI

extension View {
    /// Applies neutral ink styling to button label
    /// (`SettingsTheme.ink`, `neutralMenuLabel()`, `settingsActionButton()`,
    /// `SettingsBorderedSealTests`, `SettingsLabelNeutralityTests`, #771).
    func neutralButtonLabel() -> some View {
        tint(SettingsTheme.ink)
            .foregroundStyle(SettingsTheme.ink)
    }
}
