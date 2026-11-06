import SwiftUI

@testable import KiwiDesk

/// A tile's or card's hover tokens (#3042), kept here for the main
/// suite's length (§2.1).
extension SettingsThemeTokenTests {
    static let hoverPins: [Pin] = [
        Pin(
            "hoverEdge",
            0x5F_8F_35,
            0xAA_CB_5D,
            SettingsTheme.hoverEdge
        ),
        Pin(
            "hoverRiseShadow",
            0x12_25_1A,
            0x00_00_00,
            SettingsTheme.hoverRiseShadow,
            lightAlpha: 0.20,
            darkAlpha: 0.80
        ),
    ]
}
