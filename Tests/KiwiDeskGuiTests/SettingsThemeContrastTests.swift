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
        /// A translucent fill the render lays over the surface
        /// BEFORE the ink — the offer chip's accent wash (17a).
        /// Same argument as `inkAlpha` from the other side:
        /// measuring the ink against the bare token flatters a
        /// pairing whose real ground is the composite, and an
        /// accent wash moves the ground toward the ink's own
        /// hue, which is the direction that costs ratio.
        let wash: (color: Color, alpha: Double)?

        init(
            _ name: String,
            _ ink: Color,
            on surface: Color,
            washedWith wash: (color: Color, alpha: Double)? =
                nil,
            floor: Double = 4.5,
            inkAlpha: Double = 1
        ) {
            self.name = name
            self.ink = ink
            self.surface = surface
            self.wash = wash
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
        // The seal's two state fills. Pressed is an ENABLED
        // control and owes the text floor; disabled takes 3.0,
        // the suite's existing second floor — the verb has to
        // stay readable enough to say WHICH action is
        // unavailable, while holding it to 4.5 would erase the
        // signal that it is (#1198).
        Pairing(
            "accentInk on accentPressed",
            SettingsTheme.accentInk,
            on: SettingsTheme.accentPressed
        ),
        Pairing(
            "accentInk on accentDisabled",
            SettingsTheme.accentInk,
            on: SettingsTheme.accentDisabled,
            floor: 3.0
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
        // The narrow-window "Show preview" chip (17a): ordinary
        // ink on a card plane the render washes with the accent
        // at the search notice's strength.
        Pairing(
            "ink on the washed offer chip",
            SettingsTheme.ink,
            on: SettingsTheme.card,
            washedWith: (
                SettingsTheme.accent,
                Double(SettingsTheme.searchNoticeFillOpacity)
            )
        ),
    ]

    @Test("every drawn pairing clears its floor in both modes")
    func pairingsClearTheirFloors() throws {
        // A scan that measured nothing would pass having
        // looked at nothing (#635).
        #expect(!pairings.isEmpty)
        for pairing in pairings {
            for dark in [false, true] {
                let ratio = try ThemeContrast.contrast(
                    pairing.ink,
                    over: pairing.surface,
                    wash: pairing.wash,
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
}
