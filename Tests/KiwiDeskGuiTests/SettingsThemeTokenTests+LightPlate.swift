import SwiftUI

@testable import KiwiDesk

/// The light plate's pins (#2859 ruling 3), kept here for the
/// main suite's length (§2.1): fixed in both modes for
/// `previewPlate`'s reason — the window's appearance never
/// repaints a plate, the look's verdict picks which one draws.
extension SettingsThemeTokenTests {
    static let lightPlatePins: [Pin] = [
        Pin("lightPlate", 0xDF_E6_DC, 0xDF_E6_DC, SettingsTheme.lightPlate),
        Pin("lightEdge", 0xC6_CF_C4, 0xC6_CF_C4, SettingsTheme.lightEdge),
        Pin("lightWell", 0xEC_F0_EA, 0xEC_F0_EA, SettingsTheme.lightWell),
        Pin(
            "lightWindow",
            0xF8_FA_F6,
            0xF8_FA_F6,
            SettingsTheme.lightWindow
        ),
        Pin(
            "lightOutline",
            0xBC_C5_BA,
            0xBC_C5_BA,
            SettingsTheme.lightOutline
        ),
        Pin("lightGhost", 0xD5_DC_D2, 0xD5_DC_D2, SettingsTheme.lightGhost),
        Pin(
            "lightGhostEdge",
            0xA1_AC_A1,
            0xA1_AC_A1,
            SettingsTheme.lightGhostEdge
        ),
        Pin("lightGap", 0xB6_BF_B5, 0xB6_BF_B5, SettingsTheme.lightGap),
        Pin("lightFrame", 0xA6_B0_A6, 0xA6_B0_A6, SettingsTheme.lightFrame),
        Pin("lightMark", 0x6E_7C_71, 0x6E_7C_71, SettingsTheme.lightMark),
        Pin("lightInk", 0x2B_3B_31, 0x2B_3B_31, SettingsTheme.lightInk),
        // The bound key's glyph on the accent: its own token now
        // the plate beneath the board can change.
        Pin("keyGlyph", 0x12_25_1A, 0x12_25_1A, SettingsTheme.keyGlyph),
    ]
}
