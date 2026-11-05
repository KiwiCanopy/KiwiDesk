import SwiftUI

@testable import KiwiDesk

/// What the header bar draws directly on its own ground. Its chips
/// and switch are measured on `card` and `page`, the two values
/// `headerGround` resolves to.
extension SettingsThemeContrastTests {
    static let header: [Pairing] = [
        Pairing(
            "ink on the header",
            SettingsTheme.ink,
            on: SettingsTheme.headerGround
        ),
        Pairing(
            "ink2 on the header",
            SettingsTheme.ink2,
            on: SettingsTheme.headerGround
        ),
        Pairing(
            "warningInk on the header",
            SettingsTheme.warningInk,
            on: SettingsTheme.headerGround
        ),
    ]
}
