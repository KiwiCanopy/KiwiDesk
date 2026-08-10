import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk

/// The dark pass's verdict as a guard (#678 turn 16): every
/// ink/surface pairing the Settings tree actually draws clears
/// its WCAG floor in BOTH appearances — 4.5:1 for text, 3.0:1
/// for the board's non-text marks.
///
/// **Derived, never restated** (rule-authoring.md): each ratio
/// is computed from the SHIPPED tokens, resolved under `.aqua`
/// and `.darkAqua` exactly as the token suite resolves them —
/// so retuning a hex moves these numbers with it, and a retune
/// that sinks a pairing reds here with no table to forget. The
/// pass that motivated it: `ink3`'s first correction cleared
/// `card` and still missed `panel` and `sunken` in light
/// (4.15/4.17), because the check was a hand measurement of one
/// pairing.
///
/// Scope, stated as the obligation it is: **a change that draws
/// an ink on a surface it did not draw on before adds the
/// pairing here in the same change set** — the list is
/// hand-kept, and a pairing it misses is measured by nobody
/// (the board's bound-key glyph shipped unmeasured for a day).
/// `accent` as a control FILL on light surfaces measures ~2.2:1
/// and is the platform's own convention for tinted controls (a
/// selected state never rides colour alone here — the font step
/// carries it too), so fills-on-surface are deliberately not
/// rows; the board's RING pairs are `ColorVision`-governed in
/// `KeyboardRingSeparationTests` — one authority per pairing.
@MainActor
@Suite("Settings theme contrast floors")
struct SettingsThemeContrastTests {
    private struct Pairing {
        let name: String
        let ink: Color
        let surface: Color
        let floor: Double
        /// The alpha the RENDER applies to the ink — the
        /// measured colour is the composite over the surface,
        /// because measuring a translucent ink at full alpha
        /// flatters the drawn pairing (code review 2026-08-10:
        /// the board's free-key glyph draws plateInk at 0.75).
        let inkAlpha: Double

        init(
            _ name: String,
            _ ink: Color,
            on surface: Color,
            floor: Double = 4.5,
            inkAlpha: Double = 1
        ) {
            self.name = name
            self.ink = ink
            self.surface = surface
            self.floor = floor
            self.inkAlpha = inkAlpha
        }
    }

    /// Every ink on every surface it is drawn on. Fixed-ground
    /// pairings (the plate, the pill, the board) appear once —
    /// their both-modes check is the same check twice, which is
    /// the point of running both.
    private let pairings: [Pairing] = [
        Pairing(
            "ink on page",
            SettingsTheme.ink,
            on: SettingsTheme.page
        ),
        Pairing(
            "ink on card",
            SettingsTheme.ink,
            on: SettingsTheme.card
        ),
        Pairing(
            "ink on panel",
            SettingsTheme.ink,
            on: SettingsTheme.panel
        ),
        Pairing(
            "ink on sunken",
            SettingsTheme.ink,
            on: SettingsTheme.sunken
        ),
        Pairing(
            "ink2 on page",
            SettingsTheme.ink2,
            on: SettingsTheme.page
        ),
        Pairing(
            "ink2 on card",
            SettingsTheme.ink2,
            on: SettingsTheme.card
        ),
        Pairing(
            "ink2 on panel",
            SettingsTheme.ink2,
            on: SettingsTheme.panel
        ),
        Pairing(
            "ink2 on sunken",
            SettingsTheme.ink2,
            on: SettingsTheme.sunken
        ),
        Pairing(
            "ink3 on page",
            SettingsTheme.ink3,
            on: SettingsTheme.page
        ),
        Pairing(
            "ink3 on card",
            SettingsTheme.ink3,
            on: SettingsTheme.card
        ),
        Pairing(
            "ink3 on panel",
            SettingsTheme.ink3,
            on: SettingsTheme.panel
        ),
        Pairing(
            "ink3 on sunken",
            SettingsTheme.ink3,
            on: SettingsTheme.sunken
        ),
        Pairing(
            "groupHeading on card",
            SettingsTheme.groupHeading,
            on: SettingsTheme.card
        ),
        Pairing(
            "groupHeading on panel",
            SettingsTheme.groupHeading,
            on: SettingsTheme.panel
        ),
        Pairing(
            "groupHeading on sunken",
            SettingsTheme.groupHeading,
            on: SettingsTheme.sunken
        ),
        Pairing(
            "accentInk on accent",
            SettingsTheme.accentInk,
            on: SettingsTheme.accent
        ),
        Pairing(
            "savePillInk on savePill",
            SettingsTheme.savePillInk,
            on: SettingsTheme.savePill
        ),
        Pairing(
            "plateInk on previewPlate",
            SettingsTheme.plateInk,
            on: SettingsTheme.previewPlate
        ),
        Pairing(
            "warningInk on warningSurface",
            SettingsTheme.warningInk,
            on: SettingsTheme.warningSurface
        ),
        Pairing(
            "warningInk on card",
            SettingsTheme.warningInk,
            on: SettingsTheme.card
        ),
        Pairing(
            "warningInk on page",
            SettingsTheme.warningInk,
            on: SettingsTheme.page
        ),
        Pairing(
            "danger on card",
            SettingsTheme.danger,
            on: SettingsTheme.card
        ),
        Pairing(
            "danger on page",
            SettingsTheme.danger,
            on: SettingsTheme.page
        ),
        Pairing(
            "danger on sunken",
            SettingsTheme.danger,
            on: SettingsTheme.sunken
        ),
        // The board's RING pairs are deliberately absent: the
        // repo's ruled measure for them is `ColorVision`
        // separation (`KeyboardRingSeparationTests` — conflict
        // on accent scores 136.6 against a floor of 60 there
        // while WCAG luminance gives it 2.5, because a red on
        // a green separates by hue, which luminance cannot
        // see and a 2 pt solid ring does not need). One
        // authority per pairing, and theirs is that suite.
        Pairing(
            "plateInk glyphs on keyFree",
            SettingsTheme.plateInk,
            on: SettingsTheme.keyFree,
            inkAlpha: 0.75
        ),
        // The bound key's glyph — `KeyCap.ink` draws
        // previewPlate on the accent fill.
        Pairing(
            "previewPlate glyph on accent",
            SettingsTheme.previewPlate,
            on: SettingsTheme.accent
        ),
    ]

    @Test("every drawn pairing clears its floor in both modes")
    func pairingsClearTheirFloors() throws {
        // A scan that measured nothing would pass having
        // looked at nothing (#635).
        #expect(!pairings.isEmpty)
        for pairing in pairings {
            for dark in [false, true] {
                let ratio = try contrast(
                    pairing.ink,
                    over: pairing.surface,
                    inkAlpha: pairing.inkAlpha,
                    dark: dark
                )
                #expect(
                    ratio >= pairing.floor,
                    Comment(
                        rawValue:
                            "\(pairing.name) "
                            + (dark ? "dark" : "light")
                            + String(
                                format: ": %.2f under %.1f",
                                ratio,
                                pairing.floor
                            )
                    )
                )
            }
        }
    }

    // MARK: - WCAG arithmetic over resolved tokens

    /// Contrast of the ink AS DRAWN — alpha-composited over the
    /// surface first when the render applies an opacity.
    private func contrast(
        _ ink: Color,
        over surface: Color,
        inkAlpha: Double,
        dark: Bool
    ) throws -> Double {
        let inkRGB = try resolved(ink, dark: dark)
        let surfaceRGB = try resolved(surface, dark: dark)
        let drawn = (
            r: inkAlpha * inkRGB.r
                + (1 - inkAlpha) * surfaceRGB.r,
            g: inkAlpha * inkRGB.g
                + (1 - inkAlpha) * surfaceRGB.g,
            b: inkAlpha * inkRGB.b
                + (1 - inkAlpha) * surfaceRGB.b
        )
        let la = luminance(drawn)
        let lb = luminance(surfaceRGB)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// The token's sRGB components as resolved under one
    /// appearance — the same resolution path the token suite
    /// pins, so the two suites measure one truth.
    private func resolved(
        _ color: Color,
        dark: Bool
    ) throws -> (r: Double, g: Double, b: Double) {
        let appearance = try #require(
            NSAppearance(named: dark ? .darkAqua : .aqua)
        )
        var resolvedColor: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor =
                NSColor(color).usingColorSpace(.sRGB)
        }
        let srgb = try #require(resolvedColor)
        return (
            Double(srgb.redComponent),
            Double(srgb.greenComponent),
            Double(srgb.blueComponent)
        )
    }

    private func luminance(
        _ rgb: (r: Double, g: Double, b: Double)
    ) -> Double {
        func lin(_ v: Double) -> Double {
            v <= 0.04045
                ? v / 12.92
                : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(rgb.r) + 0.7152 * lin(rgb.g)
            + 0.0722 * lin(rgb.b)
    }
}
