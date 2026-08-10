import AppKit
import SwiftUI

/// The Settings window's colour and shape tokens (#678 turn 16b).
///
/// Every surface, ink and border in the Settings tree resolves
/// here. A hex literal beside a view is the drift this type
/// exists to end: before it, the header painted `.bar`, the cards
/// `controlBackgroundColor` and the hairlines
/// `Color.primary.opacity(0.12)`, so three neighbouring greys came
/// from three unrelated systems and no two moved together.
///
/// **A static enum, not an `@Environment` value.** Each token is a
/// `Color` wrapping `NSColor(name:dynamicProvider:)`, so light and
/// dark resolve per-draw from the *effective* appearance —
/// `AppearanceChoice.apply()` sets `NSApp.appearance` app-wide
/// (`AppearanceChoice+Scheme.swift`) and both modes follow with no
/// further plumbing. An environment theme would pay only if two
/// themes could coexist in one view tree; the appearance is
/// process-global, so they cannot, and it would tax every `body`
/// the shallow-body rule protects (`.claude/rules/gui.md`).
///
/// Same reasoning as `SettingsMetrics`, one shelf up: a constant
/// on a view is one nobody measures against.
///
/// The hex pairs are pinned by `SettingsThemeTokenTests`, which
/// resolves each token under `.aqua` and `.darkAqua` and holds the
/// only copy of the table. Do not restate a hex here.
enum SettingsTheme {

    // MARK: - Surfaces

    /// The window behind everything. Flat and opaque — the
    /// prototype carries no vibrancy, and the translucent header
    /// was the single biggest "wrong colour" report (owner
    /// 2026-08-04).
    static let page = token(light: 0xFB_FC_FA, dark: 0x17_1C_19)

    /// Containers and rows: the header bar, Home cards, section
    /// containers, the footer.
    static let card = token(light: 0xFF_FF_FF, dark: 0x1E_25_21)

    /// The preview column. No consumer until Phase 4 lands the
    /// 392 pt panel; it ships now so the guard pins one whole
    /// table rather than growing a row per phase.
    static let panel = token(light: 0xF4_F6_F1, dark: 0x1A_20_1C)

    /// Disclosure interiors — and, by ruling rather than by the
    /// 16b table, the filled chips. The prototype paints chips
    /// `#F2F5EF`, within two points of this; a third near-identical
    /// light grey-green would be a token nobody could tell from
    /// its neighbour on screen.
    static let sunken = token(light: 0xF4_F7_F1, dark: 0x23_2B_26)

    /// The desktop-dark plate behind a Home card's picture
    /// (#786): the tile is a picture of the user's desktop, so
    /// its ground is a desktop at night, not a Settings surface.
    /// Identical in both modes for the same reason the palette
    /// inside it is (4g): what the picture shows must not change
    /// with the window's appearance. Deliberately NOT `page`'s
    /// dark `0x171C19`: in dark mode the plate must still read
    /// as sitting below the card (`0x1E_25_21`), and the page
    /// grey is within four points of it.
    static let previewPlate = token(
        light: 0x12_25_1A,
        dark: 0x12_25_1A
    )

    /// The plate's own light ink — the fallback the palette fold
    /// swaps in when the USER's ink or accent sinks into
    /// `previewPlate` (a legal palette: Lua is open, and a
    /// light-styled bar carries a dark ink that is legible on
    /// its own fill and invisible on this fixed dark ground).
    /// Identical in both modes for the plate's own reason.
    static let plateInk = token(
        light: 0xEA_F3_EE,
        dark: 0xEA_F3_EE
    )

    // MARK: - Keyboard preview key states

    /// A key the draft binds, on the Shortcuts panel's board
    /// (#678 pass 5). Fixed in both modes for `previewPlate`'s
    /// reason — the board is a picture of a keyboard sitting on
    /// that same dark ground, and what it shows must not change
    /// with the window's appearance.
    ///
    /// It went NEUTRAL for one day and came back, and the reason
    /// it left is worth recording so nobody repeats it: the
    /// measurement that condemned green was taken with the wrong
    /// metric. `ColorVision.separation` is Euclidean distance in
    /// SIMULATED sRGB; a CIE-Lab proxy used during the pass
    /// reported warm colours at 17–25 against this green, and on
    /// the repo's own measure they are 84–126, comfortably past
    /// the floor of 60. Green never denied the warm half of the
    /// wheel. Use `ColorVision`, never a re-derivation of it.

    static let keyFree = token(
        light: 0x37_46_3B,
        dark: 0x37_46_3B
    )

    /// The dashed ring on a key macOS already owns under the
    /// shown modifier. A WARNING on an otherwise-free key, not a
    /// third fill: the fill says whether the user has claimed the
    /// key, and blacking it out said "unavailable" about a key
    /// that is free under every other modifier.
    ///
    /// Measured against `keyFree` alone, because that is the only
    /// fill it can sit on — a key the user HAS bound reads bound,
    /// whatever macOS thinks. 62.9 under protanopia, floor 60.
    static let keyReserved = token(
        light: 0xE0_A3_4A,
        dark: 0xE0_A3_4A
    )

    /// The solid ring on a key two bindings both claim.
    ///

    // MARK: - Borders

    /// Every container border: card, section, header underline,
    /// footer overline. In dark it does the work fills do in
    /// light, because the surfaces there sit within ~10 points of
    /// each other.
    static let hairline = token(
        light: 0xE4_E9_E1,
        dark: 0x2C_33_2D
    )

    // MARK: - Ink

    /// Primary text: titles, row labels, card headings.
    static let ink = token(light: 0x12_25_1A, dark: 0xE6_EC_E6)

    /// Values and row detail — a card's answer subtitle, a
    /// slider's readout.
    static let ink2 = token(light: 0x55_63_5C, dark: 0xA8_B3_A9)

    /// Captions and disclosure hints, the quietest legible ink —
    /// and *legible* is the operative word: this paints a
    /// section's one-sentence explanation, which is body copy and
    /// owes 4.5:1. The 16b table's `#7C8A82` / `#869184` measured
    /// 3.61:1 on `card` in light and 4.43:1 on `sunken` in dark,
    /// so both ends moved until the worst pairing clears. A
    /// caption nobody can read is not quiet, it is missing.
    static let ink3 = token(light: 0x6B_7A_72, dark: 0x98_A2_96)

    /// The small-caps group heading ("THIS PROFILE", a disclosure
    /// interior's group label).
    ///
    /// The one pair 16b does not carry: the prototype only ever
    /// draws this on light. Owner ruled a dedicated dark
    /// counterpart (2026-08-04) over reusing `accent` — at full
    /// accent strength a 10 pt small-caps label reads as something
    /// clickable — and over `ink3`, which would drop the green
    /// identity in both modes.
    static let groupHeading = token(
        light: 0x50_6C_37,
        dark: 0x9B_B0_7E
    )

    // MARK: - Accent

    /// KiwiDesk green, on controls and chrome alike. Owner ruled
    /// the full-kiwi option (2026-08-04): the window is tinted
    /// with this rather than the user's system accent, which is
    /// what the prototype shows and what the fidelity complaint
    /// pointed at. Deliberately identical in both modes — the
    /// brand should not change hue with the appearance.
    static let accent = token(light: 0x8D_B3_54, dark: 0x8D_B3_54)

    /// Text and glyphs drawn ON `accent`. Stays dark in both
    /// modes: kiwi is a mid-light green, so white on it fails
    /// contrast whatever the appearance says.
    static let accentInk = token(
        light: 0x12_25_1A,
        dark: 0x12_25_1A
    )

    /// A switch knob riding an accent track — the one token that
    /// flips, because a white knob glares against dark chrome.
    /// Its first consumer is Phase 4's control restyle; it ships
    /// with the table for the same reason `panel` does.
    static let onAccentKnob = token(
        light: 0xFF_FF_FF,
        dark: 0x12_25_1A
    )

    /// The floating save pill's plate (#678 turn 9; owner
    /// 2026-08-09 overturned the docked-footer ruling after
    /// seeing the two side by side). Dark chrome floating OVER
    /// the content, so on light it is the deep desktop green;
    /// in dark mode it drops to the preview-frame fill 16b pins
    /// BELOW the page (`0x0C1410`) so it still reads as a
    /// separate plane when the page itself is near-black.
    static let savePill = token(
        light: 0x12_25_1A,
        dark: 0x0C_14_10
    )

    /// Text ON the save pill — light in both modes, the pill
    /// being dark chrome in both.
    static let savePillInk = token(
        light: 0xEA_F3_EE,
        dark: 0xEA_F3_EE
    )

    // MARK: - States

    /// The paused bar and the first-run banner's fill.
    static let warningSurface = token(
        light: 0xFD_F1_DD,
        dark: 0x3A_2A_18
    )

    /// Warning text and glyphs, including the unsaved chip's dot.
    /// Darker on light so it holds 4.5:1 against
    /// `warningSurface`.
    static let warningInk = token(
        light: 0x9A_62_00,
        dark: 0xE0_A3_4A
    )

    /// Destructive text and glyphs. Lifted in dark so it stays
    /// legible instead of sinking into `page`.
    static let danger = token(light: 0xB0_3A_2A, dark: 0xE0_82_76)

    // MARK: - Construction

    /// One dynamic colour from a light/dark `0xRRGGBB` pair.
    ///
    /// `bestMatch` rather than a raw name comparison: an
    /// appearance can be a vibrant or high-contrast variant of
    /// either mode, and those must resolve to the mode they
    /// belong to instead of silently falling through to light.
    private static func token(
        light: UInt32,
        dark: UInt32
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark =
                    appearance.bestMatch(
                        from: [.aqua, .darkAqua]
                    ) == .darkAqua
                return srgb(isDark ? dark : light)
            }
        )
    }

    private static func srgb(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
