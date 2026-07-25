import Foundation
import Testing

@testable import KiwiDeskCore

/// The lightness clause of the two-accent rule (#470).
///
/// `ColorPaletteTests.focusedAccentDistinct` pins that a bundled
/// palette's focused accent is not *equal* to its active accent —
/// the rule as it stood after the QA that found Monochrome
/// shipping `#FFFFFF == #FFFFFF`. #470 found the next failure
/// mode: a pair that is unequal, a genuinely different hue, and
/// still indistinguishable — because green↔amber is the axis
/// red-green colour-vision deficiency flattens, and the brand's
/// primary accent is green. The shipped default measured a
/// separation of 22/441 under simulated protanopia.
///
/// The fix was lightness, not hue: `#C2790A` clears the active
/// green in a channel every CVD type preserves. This suite pins
/// that gap for the **derived default palette only**. It is
/// deliberately not a catalog-wide assertion — Kiwi Neon and Kiwi
/// Gold sit below any threshold worth setting, and retuning them
/// is an eye-confirm call that belongs with its own change (see
/// docs/design-decisions.md, palette-coherence heuristics).
@Suite("Space Bar accent separation")
struct SpaceBarAccentSeparationTests {
    /// Relative luminance (WCAG 2.1), the perceptual stand-in for
    /// "lightness" here: it is what a CVD simulation preserves,
    /// and it needs no colour-space dependency to compute.
    private func luminance(_ hex: String) -> Double? {
        guard let rgb = DragVisual.parseHex(hex) else { return nil }
        func channel(_ value: Double) -> Double {
            value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        // `parseHex` already normalizes each channel to 0...1.
        return 0.2126 * channel(rgb.red)
            + 0.7152 * channel(rgb.green)
            + 0.0722 * channel(rgb.blue)
    }

    private var style: SpaceBarStyle { SpaceBarStyle() }

    @Test("The default focused accent is darker than the active")
    func focusedIsDarkerThanActive() throws {
        let active = try #require(luminance(style.activeItemColor))
        let focused = try #require(
            luminance(style.focusedItemColor)
        )
        // Direction matters as much as magnitude: the accepted
        // trade of #470 is that focused reads *darker*. A retune
        // that brightens it back past the green re-opens the
        // defect even if the gap survives.
        #expect(focused < active)
    }

    @Test("The default accent pair keeps a real lightness gap")
    func defaultPairHasLightnessGap() throws {
        let active = try #require(luminance(style.activeItemColor))
        let focused = try #require(
            luminance(style.focusedItemColor)
        )
        // Contrast ratio between the two accents. This is a
        // regression floor sized against measured values, not an
        // absolute standard — the number is small because it
        // compares two accents to each other, not text to a
        // background. Shipped `#C2790A`: 1.443. Pre-#470
        // `#E8A33D`: 1.118, the pair that simulated to protan
        // separation 22. The two near-miss retunes considered in
        // #470 also land below: `#F0B858` 1.344 (protan 23),
        // `#E09B2E` 1.022. 1.35 admits the shipped pair and
        // rejects every one of those, without pinning the hex.
        let hi = max(active, focused)
        let lo = min(active, focused)
        let ratio = (hi + 0.05) / (lo + 0.05)
        let detail =
            "active \(style.activeItemColor) vs focused "
            + "\(style.focusedItemColor) differ by only "
            + "\(ratio) — hue alone does not survive "
            + "colour-vision deficiency (#470)"
        #expect(ratio >= 1.35, Comment(rawValue: detail))
    }

    @Test("The derived default palette carries the same pair")
    func derivedPaletteMatchesTheStruct() {
        // "Kiwi (Default)" is read from the struct defaults at
        // load, so the palette shelf and the struct can never
        // disagree — pin that, since the gap above is only
        // meaningful if the palette actually shows it.
        let palette = PaletteCatalog.defaultPalette()
        #expect(
            palette.colors["space_bar.focused_item_color"]
                == style.focusedItemColor
        )
        #expect(
            palette.colors["space_bar.active_item_color"]
                == style.activeItemColor
        )
    }
}
