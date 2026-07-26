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
/// a palette that has no defect — and would have blocked the
/// catalog-wide tightening #511 went on to do. Guarding the real
/// quantity is what kept that door open.
///
/// Scope is the **whole bundled catalog** (#511), and it
/// subsumes `ColorPaletteTests.focusedAccentDistinct` — an equal
/// pair separates at 0, so anything that guard catches this one
/// catches too, plus the missing-key and `#FFFFFF` vs
/// `#FFFFFFFF` cases it waves through. That one is kept as the
/// cheap check; don't read the pair as split coverage.
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

    /// The floor every bundled active/focused pair must clear.
    ///
    /// Set by the shipped default and nothing else: it measures
    /// 93, the *lowest* in the catalog, where every other palette
    /// now sits at 181 or above. 60 is comfortably above the 22 of
    /// the pre-#470 default and above both near-miss retunes
    /// considered at the time (`#F0B858` 23, `#E09B2E` 39), while
    /// leaving room to retune a hex without tripping a guard on a
    /// colour that is actually fine.
    ///
    /// **It is a floor, not a target.** A new bundled palette that
    /// lands at 61 passes while being far worse than anything in
    /// the catalog; the standard the #511 retunes were actually
    /// held to was parity with that 181+ band. Aim there and let
    /// this catch the disasters.
    ///
    /// If an eye-confirm asks for a different accent and this goes
    /// red: re-measure, and move the floor only if the new
    /// *measurement* justifies it. Lowering it to fit a pick
    /// discards the argument the number encodes.
    private static let separationFloor: Double = 60

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

    @Test("The simulation reproduces the numbers #470 was decided on")
    func simulationMatchesTheRecordedMeasurements() throws {
        // Pin the metric itself before pinning anything with it —
        // otherwise a broken simulation makes every assertion
        // below pass vacuously. These are the figures quoted in
        // docs/design-decisions.md and the commit that set the
        // default; they are what the decision was made on.
        let old = try #require(ColorVision.separation("#8DB354", "#E8A33D"))
        let new = try #require(ColorVision.separation("#8DB354", "#C2790A"))
        let coolPrimary = try #require(
            ColorVision.separation("#64D2FF", "#FF9F0A")
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
            ColorVision.separation(
                style.activeItemColor,
                style.focusedItemColor
            )
        )
        // The shipped pair measures 93; the floor is 60 (see
        // `separationFloor`). Kept as its own test
        // alongside the catalog sweep because the struct defaults
        // are what a user with no palette applied actually sees.
        let detail =
            "active \(style.activeItemColor) vs focused "
            + "\(style.focusedItemColor) separate by only "
            + "\(gap)/441 under simulated protanopia — hue alone "
            + "does not survive it against a green primary (#470)"
        #expect(gap >= Self.separationFloor, Comment(rawValue: detail))
    }

    /// The catalog-wide half of the clause (#511).
    ///
    /// Beyond the gap itself this pins two authoring rules that
    /// were previously only conventions: a bundled palette
    /// **defines both accent keys** (the inequality guard skips a
    /// palette that omits either, so an absent focused accent read
    /// as compliance), and both are **opaque** — `parseHex`
    /// accepts `#RRGGBBAA`, and the catalog does use alpha for the
    /// muted item tier, so a translucent accent is a plausible
    /// slip that would clear the distance check on its RGB alone.
    @Test("Every bundled accent pair survives red-green vision loss")
    func everyBundledPairSeparatesUnderProtanopia() throws {
        let palettes = PaletteCatalog.bundled()
        // `PaletteCatalog.authored()` soft-fails to `[]` on a
        // missing or malformed resource, and `bundled()` prepends
        // the derived default — so without this the sweep would
        // silently shrink to one palette and still pass, which is
        // the "guard that cannot fail" this suite exists to avoid.
        #expect(palettes.count == 9)
        for palette in palettes {
            let name = palette.name
            // `#expect`, not `#require`: a require here aborts the
            // sweep at the first offender, so a two-palette
            // regression would report as one.
            guard
                let active =
                    palette.colors["space_bar.active_item_color"],
                let focused =
                    palette.colors["space_bar.focused_item_color"]
            else {
                Issue.record("\(name) omits an accent key")
                continue
            }
            for hex in [active, focused] {
                let rgb = DragVisual.parseHex(hex)
                #expect(
                    rgb?.alpha == 1,
                    Comment(rawValue: "\(name) \(hex) is not opaque")
                )
            }
            guard let gap = ColorVision.separation(active, focused) else {
                Issue.record("\(name) has an unparseable accent")
                continue
            }
            let detail =
                "\(name): active \(active) vs focused \(focused) "
                + "separate by only \(gap)/441 under simulated "
                + "protanopia (#511)"
            #expect(gap >= Self.separationFloor, Comment(rawValue: detail))
        }
    }

    @Test("The default focused accent is darker than the active")
    func focusedIsDarkerThanActive() throws {
        let active = try #require(
            ColorVision.luminance(style.activeItemColor)
        )
        let focused = try #require(
            ColorVision.luminance(style.focusedItemColor)
        )
        // Direction, not magnitude: the accepted trade of #470 is
        // that focused reads *darker*. Worth pinning separately
        // because it is the half a reader notices on screen, and
        // because it is what the group-count badge's contrast
        // regression (documented in design-decisions.md) hangs on.
        #expect(focused < active)
    }

    @Test("Badge ink is legible on the badge chip")
    func badgeInkClearsContrastOnItsChip() throws {
        let ratio = try #require(
            ColorVision.contrast(
                style.groupBadgeTextColor,
                style.groupBadgeColor
            )
        )
        // The badge numeral is small text, so 4.5:1. This exists
        // because the pairing broke once: a 2026-07-20 change had
        // the badge take `focusedItemColor` when its app was
        // focused, which silently coupled the badge's legibility
        // to an accent tuned against a *different* background —
        // and #470's darkening of that accent took the pair to
        // 2.10:1. Badge ink now stays `groupBadgeTextColor`
        // (#470, ui-designer consult); this pins that the two
        // badge fields are chosen against each other and nothing
        // else re-couples them.
        #expect(ratio >= 4.5)
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
