import Testing

@testable import KiwiDeskCore

/// The negative controls of `BorderRingSeparationTests` (#1384) —
/// the hexes the ring rules must REFUSE, each measured on
/// `ColorVision` so the number a sweep clause asserts against is
/// proven reachable rather than asserted about. Split out of the
/// sweep suite on size alone; the constants are read from it.
@Suite("Border ring separation controls")
struct BorderRingSeparationControlTests {
    private typealias Sweep = BorderRingSeparationTests

    /// The negative control for Sunset's "not lifted" ruling: the
    /// shared system grey the other dark palettes take, over a
    /// white wallpaper, lands on the pink's protan grey. A
    /// literal well under the floor rather than a fraction of it —
    /// this measures a hex Sunset must never ship and cannot move
    /// with a floor retune.
    @Test("A lifted Sunset grey collapses against the pink")
    func aLiftedSunsetGreyCollapses() throws {
        let focused = try #require(
            ColorVision.composite("#FF8099", over: "#FFFFFF")
        )
        let lifted = try #require(
            ColorVision.composite("#8E8E93E6", over: "#FFFFFF")
        )
        let gap = try #require(ColorVision.separation(focused, lifted))
        #expect(gap < ColorVision.separationFloor)
        #expect(gap < 12)
    }

    /// The negative control for the own-contrast floor: Slate's
    /// retired grey at the NEW alpha. Proves the floor tells
    /// lightness from alpha — this hex clears the band and both
    /// pair clauses.
    @Test("A grey lifted in alpha alone is no ring")
    func aGreyLiftedInAlphaAloneIsNoRing() throws {
        let own = try #require(
            Sweep.compositedContrast("#48484AE6", on: "#000000")
        )
        #expect(own < Sweep.ownContrastFloor)
    }

    /// The negative control for the parity band: the device pick
    /// #1384 refused. Proves the band reachable — a grey more
    /// than twice the indigo's contrast is dominance inverted,
    /// not parity.
    @Test("The refused Ultraviolet pick inverts dominance")
    func theRefusedUltravioletPickInvertsDominance() throws {
        let indigo = try #require(
            Sweep.compositedContrast("#5E5CE6", on: "#000000")
        )
        let pick = try #require(
            Sweep.compositedContrast("#BFBFBFE6", on: "#000000")
        )
        #expect(pick > indigo * Sweep.parityBand)
        #expect(pick > indigo * 2)
    }
}
