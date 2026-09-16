import SwiftUI

extension View {
    /// Styles borderless menu and menu-style picker labels in
    /// neutral ink (`SettingsLabelNeutralityTests`, #678 turn
    /// 16b). A picker needs it since macOS 27, which draws a
    /// menu-style picker's label from the tint while the window
    /// is key (#1502).
    func neutralMenuLabel() -> some View {
        tint(SettingsTheme.ink)
            .foregroundStyle(SettingsTheme.ink)
    }
}
