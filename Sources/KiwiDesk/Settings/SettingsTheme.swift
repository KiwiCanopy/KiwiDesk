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

    // MARK: - Shapes

    // The metrics, and the boundary they are admitted on —
    // stated here, at the head of the section, so the next area
    // meets it by position rather than by archaeology (#758
    // argued it inside one docstring further down, which the
    // second area then cited as "the ruling above" while
    // standing above it).
    //
    // AREA-SCOPED numbers in an app-wide theme, deliberately: a
    // number some arithmetic derives from lives BESIDE that
    // arithmetic (the Monitors picture's capacity maths owns
    // its own), while pure chrome — strokes, radii, stands,
    // things nothing computes on — lives here with the radii so
    // one restyle is one file.
    //
    // The colour tokens' totality guard cannot see these: it
    // parses `= token(` (`SettingsThemeTokenTests`,
    // `SettingsThemeWiringTests`). Metrics are covered by their
    // area's own chrome suite instead —
    // `MonitorsChromeWiringTests`, `PaletteShelfChromeTests` —
    // and `SettingsThemeMetricTests` is what refuses a metric
    // that belongs to neither, so a third area cannot add one
    // and quietly leave it unguarded.

    /// A Home card's corner. The prototype's cards are flat —
    /// fill plus hairline, no shadow — so the radius carries the
    /// softness a shadow would have.
    static let cardRadius: CGFloat = 14

    /// A section container's corner. Larger than a card's on
    /// purpose: a section is the outer box, and equal radii make
    /// nested rounds read as a mistake.
    static let sectionRadius: CGFloat = 16

    /// A disclosure interior's corner, one step inside a section.
    static let disclosureRadius: CGFloat = 12

    /// A chip's corner. Rounded-rect, not a capsule — the
    /// prototype's chips are square-ish tokens, and a capsule
    /// beside a segmented control reads as a second control.
    static let chipRadius: CGFloat = 9

    /// The Monitors picture's card stroke at rest — heavier than
    /// the app's hairline so a display card reads as an OBJECT
    /// on the recessed well rather than as outlined content
    /// (#758). Selection keeps its own, still-heavier weight:
    /// the border is the SELECTED channel, and the two weights
    /// must stay apart or one state swallows the other.
    static let monitorCardStroke: CGFloat = 1.5
    static let monitorCardStrokeSelected: CGFloat = 3

    /// A palette tile's frame at rest and once it is the applied
    /// one (#757). The shelf's whole content is colour, so the
    /// frame is the ONLY channel selection can use — no fill, no
    /// glyph on the picture — and the two weights follow the
    /// Monitors picture's ruling above: keep them apart or one
    /// state swallows the other. Lighter than a display card's
    /// pair because a palette tile is one of many in a grid
    /// rather than an object on a well.
    static let paletteCardStroke: CGFloat = 1
    static let paletteCardStrokeApplied: CGFloat = 2

    /// A display card's stand: the foot as a share of the card's
    /// width and the neck as a share of the foot, each clamped.
    /// Long enough that the card sits ON its foot rather than
    /// floating above a speck (#758); the clamps stop the same
    /// shares giving a laptop thumbnail a plinth. The foot's
    /// FLOOR stays at its pre-#758 value: on a floor-sized card
    /// (`MonitorArrangement.minimumCard`) the raised share
    /// alone reads as a plinth, and neighbouring floored cards'
    /// feet fuse into one rail (ui-designer, 2026-08-09).
    ///
    /// The section header states the boundary these are
    /// admitted on; `MonitorsChromeWiringTests`' themed-metrics
    /// test is this pair's wiring guard, the capacity arithmetic
    /// they are NOT part of living in `MonitorCardChips`.
    static let monitorStandScale: CGFloat = 0.52
    static let monitorStandMin: CGFloat = 44
    static let monitorStandMax: CGFloat = 230
    static let monitorNeckScale: CGFloat = 0.26
    static let monitorNeckMin: CGFloat = 14
    static let monitorNeckMax: CGFloat = 44

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
