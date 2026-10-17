import SwiftUI

extension View {
    /// The action button: the button-chip face, lifting grey under
    /// the pointer like every chip (#2377), paired with label
    /// neutralization (`SettingsBorderedSealTests`,
    /// `SettingsLabelNeutralityTests`, #759, #771).
    func settingsActionButton() -> some View {
        buttonStyle(ButtonChipStyle())
            .neutralButtonLabel()
    }
}
