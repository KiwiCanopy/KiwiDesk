import SwiftUI

extension View {
    /// The one way a Settings action button takes the bordered
    /// style: paired with its label neutralisation BY CONSTRUCTION
    /// (#678 turn 16b tinted the window kiwi, #759; the first fix
    /// left style and neutralisation two decisions a site could
    /// get half right, #771). A `.destructive` button keeps the
    /// raw style — the system red IS the warning — via
    /// `SettingsBorderedSealTests`' `borderedExempt` map;
    /// `.borderedProminent` never comes through here. The
    /// raw-style guard skips this file by NAME
    /// (`SettingsLabelNeutralityTests`).
    func settingsActionButton() -> some View {
        buttonStyle(.bordered)
            .neutralButtonLabel()
    }
}
