import SwiftUI

extension View {
    /// Styles borderless menu labels in neutral ink
    /// (`SettingsLabelNeutralityTests`, #678 turn 16b).
    func neutralMenuLabel() -> some View {
        tint(SettingsTheme.ink)
            .foregroundStyle(SettingsTheme.ink)
    }
}
