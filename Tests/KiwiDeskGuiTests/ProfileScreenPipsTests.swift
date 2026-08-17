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
    /// Stated limit, shared with the preset card's suite: the
    /// never-exactly-one correction inside `OverflowSplit` is
    /// UNREACHABLE at the marker capacity this row passes
    /// (`slots - 1`), so any property here holds by the early
    /// return. Deleting the correction leaves this suite green and
    /// reds `OverflowSplitTests` (guard-prover, 2026-08-17).
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
    /// counted is the profile's own screen count — asserted as
    /// hand-written pairs, not as `shown + hidden == count`.
    ///
    /// That identity is ENTAILED by `hidden`'s own definition
    /// (`max(count - shown, 0)`) for every `shown <= count`, so
    /// it could only red on a mutation making `shown > count`,
    /// which `drawsEveryScreenWhileItFits` already catches. The
    /// pairs below are independent of the production arithmetic.
    @Test("the split is the expected pair at each count")
    func splitIsTheExpectedPair() {
        let expected: [Int: (shown: Int, hidden: Int)] = [
            0: (0, 0),
            1: (1, 0),
            3: (3, 0),
            4: (4, 0),
            5: (3, 2),
            6: (3, 3),
            12: (3, 9),
        ]
        for (count, want) in expected {
            let view = pips(count)
            #expect(
                view.shown == want.shown,
                Comment(rawValue: "\(count) screens: shown")
            )
            #expect(
                view.hidden == want.hidden,
                Comment(rawValue: "\(count) screens: hidden")
            )
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

    /// The reserved width is DERIVED, asserted against
    /// hand-computed widths at slot counts this app does NOT
    /// ship.
    ///
    /// The first cut of this test recomputed the production
    /// formula and compared the two, which is a mirror: a
    /// guard-prover run replaced the whole derivation with the
    /// literal `81` — today's value — and all seven tests stayed
    /// green. Only the composite (literal PLUS a cap change)
    /// reddened, so the guard saw the harm and not the latent
    /// state that makes it possible. These numbers are computed
    /// by hand, not by the formula under test.
    @Test("the slot width is the grammar, not a literal")
    func slotWidthIsTheGrammar() {
        let pip = CGSize(width: 18, height: 12)
        // 1 slot: one pip, no gap.
        #expect(
            ProfileScreenPips.slotWidth(
                slots: 1,
                screen: pip,
                gap: 3
            ) == 18
        )
        // 2 slots: 36 + one 3 pt gap.
        #expect(
            ProfileScreenPips.slotWidth(
                slots: 2,
                screen: pip,
                gap: 3
            ) == 39
        )
        // 5 slots: 90 + four gaps — past the shipped count, so a
        // literal agreeing with today's 4 cannot pass this.
        #expect(
            ProfileScreenPips.slotWidth(
                slots: 5,
                screen: pip,
                gap: 3
            ) == 102
        )
        // A different pip and gap entirely: 3 × 10 + 2 × 5.
        #expect(
            ProfileScreenPips.slotWidth(
                slots: 3,
                screen: CGSize(width: 10, height: 8),
                gap: 5
            ) == 40
        )
    }

    /// And a row's width IS that grammar at whatever the LIST
    /// reserved — the join, without which the parameterized
    /// function above could be correct while the view drew
    /// something else.
    @Test("a row's width is the grammar at its reservation")
    func rowWidthUsesTheGrammar() {
        for reserved in 1...ProfileScreenPips.slots {
            let view = ProfileScreenPips(
                count: 1,
                reservedSlots: reserved
            )
            #expect(
                view.slotWidth
                    == ProfileScreenPips.slotWidth(
                        slots: reserved,
                        screen: ProfileScreenPips.screen,
                        gap: ProfileScreenPips.gap
                    )
            )
        }
    }

    /// The defect this reservation exists to fix, pinned by its
    /// arithmetic: a list where nothing has more than one screen
    /// reserves ONE slot, not the cap.
    ///
    /// Reserving the cap put a single 20 pt outline at the left
    /// of an 89 pt column and stranded it ~69 pt from its own
    /// profile name — invisible to every test in this suite,
    /// caught on sight (owner, 2026-08-16).
    @Test("a one-screen list reserves one slot, not the cap")
    func oneScreenListReservesOneSlot() {
        let reserved = ProfileScreenPips.reservedSlots(
            forScreenCounts: [1, 1, 1]
        )
        #expect(reserved == 1)
        let view = ProfileScreenPips(count: 1, reservedSlots: reserved)
        #expect(view.slotWidth == ProfileScreenPips.screen.width)
    }

    /// The alignment property the reservation exists FOR: every
    /// row in one list reserves the same width whatever its own
    /// screen count, so the names line up.
    @Test("every row in a list reserves the same width")
    func rowsInAListAgreeOnWidth() {
        let counts = [1, 3, 2]
        let reserved = ProfileScreenPips.reservedSlots(
            forScreenCounts: counts
        )
        #expect(reserved == 3)
        let widths = counts.map {
            ProfileScreenPips(count: $0, reservedSlots: reserved)
                .slotWidth
        }
        #expect(Set(widths).count == 1)
    }

    /// A list wider than the cap still reserves only the cap —
    /// the "+N" chip is what carries the rest.
    @Test("a list past the cap reserves the cap")
    func listPastTheCapReservesTheCap() {
        #expect(
            ProfileScreenPips.reservedSlots(
                forScreenCounts: [9, 2]
            ) == ProfileScreenPips.slots
        )
    }

    /// An empty list still reserves a column, so the names do
    /// not jump sideways when the first profile is saved.
    @Test("an empty list still reserves one slot")
    func emptyListReservesOne() {
        #expect(
            ProfileScreenPips.reservedSlots(
                forScreenCounts: [Int]()
            ) == 1
        )
    }
}
