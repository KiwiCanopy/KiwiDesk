import SwiftUI

@testable import KiwiDesk

/// The chip and track pins of the #678 token table, kept here for
/// the main suite's length (§2.1): the ink at a per-mode alpha,
/// each stronger in dark, where a 6 % fill does not read (#1520,
/// #2047).
extension SettingsThemeTokenTests {
    static let chipPins: [Pin] = [
        // A chip's rest fill and its lift (#1520): the ink at a
        // per-mode alpha, stronger in dark, where a 6 % lift does
        // not read.
        Pin(
            "chipRest",
            0x12_25_1A,
            0xE6_EC_E6,
            SettingsTheme.chipRest,
            lightAlpha: 0.06,
            darkAlpha: 0.10
        ),
        Pin(
            "chipHover",
            0x12_25_1A,
            0xE6_EC_E6,
            SettingsTheme.chipHover,
            lightAlpha: 0.11,
            darkAlpha: 0.16
        ),
        // Held down, and the edge no state moves (#1520
        // amendment 5).
        Pin(
            "chipPressed",
            0x12_25_1A,
            0xE6_EC_E6,
            SettingsTheme.chipPressed,
            lightAlpha: 0.16,
            darkAlpha: 0.22
        ),
        Pin(
            "chipEdge",
            0x12_25_1A,
            0xE6_EC_E6,
            SettingsTheme.chipEdge,
            lightAlpha: 0.18,
            darkAlpha: 0.20
        ),
        // A segmented control's well, fill and rim (#2047).
        Pin(
            "trackFill",
            0x12_25_1A,
            0xE6_EC_E6,
            SettingsTheme.trackFill,
            lightAlpha: 0.09,
            darkAlpha: 0.12
        ),
    ]
}
