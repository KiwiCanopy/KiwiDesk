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

    /// A button opening a pop-up of its own: the native pop-up's
    /// capsule without an edge (`PopUpTriggerStyle`), paired
    /// with the same label neutralization.
    func settingsPopUpTrigger() -> some View {
        buttonStyle(PopUpTriggerStyle())
            .neutralButtonLabel()
    }
}
