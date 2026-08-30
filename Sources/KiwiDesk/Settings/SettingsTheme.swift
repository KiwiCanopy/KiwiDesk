import AppKit
import SwiftUI

/// Settings window colour and shape tokens (#678).
///
/// Dynamic `Color` values wrapping `NSColor(name:dynamicProvider:)`.
/// Hex pairs are pinned by `SettingsThemeTokenTests`.
enum SettingsTheme {

    // MARK: - Surfaces

    /// Window background behind all content.
    static let page = token(light: 0xFB_FC_FA, dark: 0x17_1C_19)

    /// Containers and rows: header bar, cards, section containers, footer.
    static let card = token(light: 0xFF_FF_FF, dark: 0x1E_25_21)

    /// Preview column panel background.
    static let panel = token(light: 0xF4_F6_F1, dark: 0x1A_20_1C)

    /// Disclosure interiors and filled chips.
    static let sunken = token(light: 0xF4_F7_F1, dark: 0x23_2B_26)

    /// Desktop-dark plate behind Home card picture (#786).
    static let previewPlate = token(
        light: 0x12_25_1A,
        dark: 0x12_25_1A
    )

    /// Plate light ink fallback when palette ink sinks into `previewPlate`.
    static let plateInk = token(
        light: 0xEA_F3_EE,
        dark: 0xEA_F3_EE
    )

    // MARK: - Keyboard preview (#678)

    /// Unbound key fill on keyboard preview.
    static let keyFree = token(
        light: 0x37_46_3B,
        dark: 0x37_46_3B
    )

    /// Dashed warning ring on free key macOS owns under shown modifier
    /// (`KeyboardRingSeparationTests`).
    static let keyReserved = token(
        light: 0xE0_A3_4A,
        dark: 0xE0_A3_4A
    )

    /// Solid ring on key in conflict with user binding or macOS reservation.
    static let keyConflict = token(
        light: 0xB0_3A_2A,
        dark: 0xB0_3A_2A
    )

    // MARK: - Borders

    /// Container border hairline: card, section, header, footer.
    static let hairline = token(
        light: 0xE4_E9_E1,
        dark: 0x2C_33_2D
    )

    /// Inset light line separating dark planes in dark mode only.
    static let planeRing = token(
        light: 0xFF_FF_FF,
        dark: 0xFF_FF_FF,
        lightAlpha: 0,
        darkAlpha: 0.14
    )

    // MARK: - Ink

    /// Primary text: titles, row labels, card headings.
    static let ink = token(light: 0x12_25_1A, dark: 0xE6_EC_E6)

    /// Values and row detail — a card's answer subtitle, a
    /// slider's readout.
    static let ink2 = token(light: 0x55_63_5C, dark: 0xA8_B3_A9)

    /// Captions and disclosure hints; contrast is tested across surfaces
    /// (`SettingsThemeContrastTests`).
    static let ink3 = token(light: 0x64_72_6A, dark: 0x98_A2_96)

    /// Small-caps group heading label.
    static let groupHeading = token(
        light: 0x50_6C_37,
        dark: 0x9B_B0_7E
    )

    // MARK: - Accent

    /// KiwiDesk green accent, identical in both modes.
    static let accent = token(light: 0x8D_B3_54, dark: 0x8D_B3_54)

    /// Text and glyphs drawn on `accent` (dark in both modes for contrast).
    static let accentInk = token(
        light: 0x12_25_1A,
        dark: 0x12_25_1A
    )

    /// Switch knob riding an accent track.
    static let onAccentKnob = token(
        light: 0xFF_FF_FF,
        dark: 0x12_25_1A
    )

    /// Floating save pill plate (#678).
    static let savePill = token(
        light: 0x12_25_1A,
        dark: 0x0C_14_10
    )

    /// Text on save pill (light in both modes).
    static let savePillInk = token(
        light: 0xEA_F3_EE,
        dark: 0xEA_F3_EE
    )

    // MARK: - States

    /// Paused bar and first-run banner fill.
    static let warningSurface = token(
        light: 0xFD_F1_DD,
        dark: 0x3A_2A_18
    )

    /// Warning text and glyphs (4.5:1 contrast on `warningSurface`).
    static let warningInk = token(
        light: 0x9A_62_00,
        dark: 0xE0_A3_4A
    )

    /// Destructive text and glyphs.
    static let danger = token(light: 0xB0_3A_2A, dark: 0xE0_82_76)

    // MARK: - Construction

    /// Dynamic colour from light/dark pair using `bestMatch` for appearance.
    private static func token(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark =
                    appearance.bestMatch(
                        from: [.aqua, .darkAqua]
                    ) == .darkAqua
                return srgb(
                    isDark ? dark : light,
                    alpha: isDark ? darkAlpha : lightAlpha
                )
            }
        )
    }

    private static func srgb(
        _ hex: UInt32,
        alpha: CGFloat
    ) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
