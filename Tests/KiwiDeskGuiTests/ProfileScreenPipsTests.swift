import CoreGraphics
import Testing

@testable import KiwiDesk

/// The saved-row screen pips' arithmetic (#789).
///
/// Asserted over the derived quantities directly rather than by
/// scanning the source for the input: a view that takes a count
/// and draws a constant satisfies every substring a scan can
/// look for while answering nothing, which is the mutation
/// `LayoutSchematicCountTests` was rewritten for. `shown` and
/// `hidden` are internal for exactly that reason.
@MainActor
@Suite("Profile screen pips")
struct ProfileScreenPipsTests {
    private func pips(_ count: Int) -> ProfileScreenPips {
        ProfileScreenPips(count: count)
    }

    /// Under the slot count every screen draws itself, so the
    /// picture IS the count and nothing is elided.
    @Test("counts at or under the slot count draw in full")
    func drawsEveryScreenWhileItFits() {
        for count in 1...ProfileScreenPips.slots {
            #expect(pips(count).shown == count)
            #expect(pips(count).hidden == 0)
        }
    }

    /// The "+N" grammar's own clause: the chip takes a slot, so
    /// it can never claim to hide exactly one — at that count the
    /// last slot draws the screen instead. This is the assertion
    /// that reds if `shown` is retuned to `slots` and the chip
    /// starts appearing at one hidden screen.
    @Test("the chip never claims to hide exactly one")
    func neverHidesExactlyOne() {
        for count in 0...12 {
            #expect(pips(count).hidden != 1)
        }
    }

    /// Past the slot count the chip takes the last slot, so one
    /// fewer screen is drawn and the chip counts the rest.
    @Test("past the slot count the chip takes the last slot")
    func chipTakesTheLastSlot() {
        let five = pips(ProfileScreenPips.slots + 1)
        #expect(five.shown == ProfileScreenPips.slots - 1)
        #expect(five.hidden == 2)
    }

    /// The drawn slots never exceed the reserved ones, at any
    /// count — the property the fixed `slotWidth` depends on, and
    /// the one a raised cap would break silently by clipping.
    @Test("the drawn slots never exceed the reserved ones")
    func neverDrawsMoreSlotsThanReserved() {
        for count in 0...40 {
            let drawn =
                pips(count).shown
                + (pips(count).hidden > 0 ? 1 : 0)
            #expect(drawn <= ProfileScreenPips.slots)
        }
    }

    /// Nothing is lost or invented: what is drawn plus what is
    /// counted is the profile's own screen count.
    @Test("shown plus hidden is the count")
    func shownPlusHiddenIsTheCount() {
        for count in 1...40 {
            let view = pips(count)
            #expect(view.shown + view.hidden == count)
        }
    }

    /// A hand-edited profile claiming zero (or fewer) screens
    /// must draw nothing rather than trap on the `ForEach` range
    /// — the same clamp `PresetScreenCard.screens` takes.
    @Test("a nonsensical count draws nothing and does not trap")
    func clampsAtZero() {
        #expect(pips(0).shown == 0)
        #expect(pips(0).hidden == 0)
        #expect(pips(-3).shown == 0)
        #expect(pips(-3).hidden == 0)
    }

    /// The reserved width is DERIVED from the slot count, the pip
    /// and the gap. A literal would let a cap change start
    /// clipping with every test still green.
    @Test("the slot width derives from the grammar")
    func slotWidthDerives() {
        let expected =
            CGFloat(ProfileScreenPips.slots)
            * ProfileScreenPips.pip.width
            + CGFloat(ProfileScreenPips.slots - 1)
            * ProfileScreenPips.gap
        #expect(ProfileScreenPips.slotWidth == expected)
    }
}
