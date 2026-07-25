import Foundation
import Testing

@testable import KiwiDeskCore

/// The colour-vision clause of the two-accent rule (#470).
///
/// `ColorPaletteTests.focusedAccentDistinct` pins that a bundled
/// palette's focused accent is not *equal* to its active accent —
/// the rule as it stood after the QA that found Monochrome
/// shipping `#FFFFFF == #FFFFFF`. #470 found the next failure
/// mode: a pair that is unequal, a genuinely different hue, and
/// still indistinguishable — because green↔amber is the axis
/// red-green colour-vision deficiency flattens, and the brand's
/// primary accent is green.
///
/// This asserts on **the same quantity `docs/design-decisions.md`
/// quotes** — separation after a simulated protanopia — rather
/// than on a lightness proxy. That matters: the two metrics
/// disagree on real palettes in this repo. True Dark's
/// `#64D2FF` / `#FF9F0A` separates at 241 (fine) while sitting
/// almost equal in lightness, so a luminance floor would condemn
/// a palette that has no defect, and would block the catalog-wide
/// tightening that is deferred to the Kiwi Neon / Kiwi Gold
/// retune. Guarding the real quantity keeps that door open.
///
/// Scope is the **derived default palette only**, deliberately:
/// Kiwi Neon (39) and Kiwi Gold (49) sit below any threshold
/// worth setting, and retuning them is an eye-confirm call that
/// belongs with its own change.
///
/// What this suite does *not* cover: the "genuinely different
/// hue" half of the two-accent rule. A dark green would pass
/// every assertion here (`#4A6B21` separates at 113 and is
/// darker than the active accent) while collapsing the two
/// states for everyone else. That half stays eyeball-only —
/// don't read a green pass here as the rule being satisfied.
@Suite("Space Bar accent separation")
struct SpaceBarAccentSeparationTests {
    private var style: SpaceBarStyle { SpaceBarStyle() }

    /// sRGB → linear, the same transfer function WCAG uses.
    private func linear(_ value: Double) -> Double {
        value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    private func components(_ hex: String) -> (
        r: Double, g: Double, b: Double
    )? {
        guard let rgb = DragVisual.parseHex(hex) else { return nil }
        // `parseHex` already normalizes each channel to 0...1.
        return (rgb.red, rgb.green, rgb.blue)
    }

    /// Both accents must be opaque for any of this to mean
    /// anything: `parseHex` accepts `#RRGGBBAA`, and the Lua
    /// setters route through it — so `"#C2790A11"` is a legal,
    /// effectively invisible value that would sail past every
    /// separation check below on its RGB alone.
    @Test("Both default accents are opaque")
    func defaultAccentsAreOpaque() throws {
        for hex in [style.activeItemColor, style.focusedItemColor] {
            let rgb = try #require(DragVisual.parseHex(hex))
            #expect(rgb.alpha == 1, Comment(rawValue: hex))
        }
    }

    /// Simulates protanopia (Viénot/Brettel LMS reduction) and
    /// returns the result in 0...255 sRGB.
    ///
    /// Protan is the strictest of the three for this palette:
    /// it is the axis a green primary and a warm focused accent
    /// collapse onto, so it is the one the rule is written
    /// against. Deutan tracks it closely; tritan is unaffected.
    private func protanope(_ hex: String) -> (
        r: Double, g: Double, b: Double
    )? {
        guard let c = components(hex) else { return nil }
        let r = linear(c.r)
        let g = linear(c.g)
        let b = linear(c.b)
        // sRGB → LMS.
        let l = 17.8824 * r + 43.5161 * g + 4.11935 * b
        let m = 3.45565 * r + 27.1554 * g + 3.86714 * b
        let s = 0.0299566 * r + 0.184309 * g + 1.46709 * b
        // The long-wavelength cone is missing: L is reconstructed
        // from the remaining two.
        let lp = 2.02344 * m - 2.52581 * s
        // LMS → sRGB.
        func encode(_ value: Double) -> Double {
            let v = min(max(value, 0), 1)
            let s =
                v <= 0.0031308
                ? 12.92 * v
                : 1.055 * pow(v, 1 / 2.4) - 0.055
            return min(max(s, 0), 1) * 255
        }
        return (
            encode(
                0.0809444479 * lp - 0.130504409 * m
                    + 0.116721066 * s
            ),
            encode(
                -0.0102485335 * lp + 0.0540193266 * m
                    - 0.113614708 * s
            ),
            encode(
                -0.000365296938 * lp - 0.00412161469 * m
                    + 0.693511405 * s
            )
        )
    }

    /// Euclidean distance in simulated sRGB, 0...441.
    private func separation(_ a: String, _ b: String) -> Double? {
        guard let x = protanope(a), let y = protanope(b) else {
            return nil
        }
        let dr = x.r - y.r
        let dg = x.g - y.g
        let db = x.b - y.b
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    @Test("The simulation reproduces the numbers #470 was decided on")
    func simulationMatchesTheRecordedMeasurements() throws {
        // Pin the metric itself before pinning anything with it —
        // otherwise a broken simulation makes every assertion
        // below pass vacuously. These are the figures quoted in
        // docs/design-decisions.md and the commit that set the
        // default; they are what the decision was made on.
        let old = try #require(separation("#8DB354", "#E8A33D"))
        let new = try #require(separation("#8DB354", "#C2790A"))
        let coolPrimary = try #require(
            separation("#64D2FF", "#FF9F0A")
        )
        #expect(abs(old - 22) < 3)
        #expect(abs(new - 93) < 3)
        // True Dark: fine on the blue↔yellow axis despite sitting
        // almost equal in lightness — the counterexample that
        // rules out a luminance proxy.
        #expect(coolPrimary > 175)
    }

    @Test("The default accent pair survives red-green vision loss")
    func defaultPairSeparatesUnderProtanopia() throws {
        let gap = try #require(
            separation(style.activeItemColor, style.focusedItemColor)
        )
        // The shipped pair measures 93. 60 is the floor:
        // comfortably above the 22 of the pre-#470 default and
        // above both near-miss retunes considered at the time
        // (`#F0B858` 23, `#E09B2E` 39), while leaving room to
        // retune the hex without tripping a guard on a colour
        // that is actually fine. It is the *green*-primary case
        // that needs this — see the suite doc comment.
        //
        // If an eye-confirm asks for a different amber and this
        // goes red: re-measure, and move the floor only if the
        // new *measurement* justifies it. Lowering it to fit a
        // pick discards the argument the number encodes.
        let detail =
            "active \(style.activeItemColor) vs focused "
            + "\(style.focusedItemColor) separate by only "
            + "\(gap)/441 under simulated protanopia — hue alone "
            + "does not survive it against a green primary (#470)"
        #expect(gap >= 60, Comment(rawValue: detail))
    }

    @Test("The default focused accent is darker than the active")
    func focusedIsDarkerThanActive() throws {
        func luminance(_ hex: String) -> Double? {
            guard let c = components(hex) else { return nil }
            return 0.2126 * linear(c.r) + 0.7152 * linear(c.g)
                + 0.0722 * linear(c.b)
        }
        let active = try #require(luminance(style.activeItemColor))
        let focused = try #require(
            luminance(style.focusedItemColor)
        )
        // Direction, not magnitude: the accepted trade of #470 is
        // that focused reads *darker*. Worth pinning separately
        // because it is the half a reader notices on screen, and
        // because it is what the group-count badge's contrast
        // regression (documented in design-decisions.md) hangs on.
        #expect(focused < active)
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
