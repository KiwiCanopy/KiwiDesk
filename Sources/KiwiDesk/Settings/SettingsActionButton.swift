import SwiftUI

extension View {
    /// Bordered action button styling paired with label neutralization
    /// (`SettingsBorderedSealTests`, `SettingsLabelNeutralityTests`,
    /// #759, #771).
    func settingsActionButton() -> some View {
        buttonStyle(.bordered)
            .neutralButtonLabel()
    }
}
