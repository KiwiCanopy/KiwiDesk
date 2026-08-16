import Testing

@testable import KiwiDesk

/// The "+N" grammar's count half, now that it is stated once
/// (`OverflowSplit`) instead of once per surface.
///
/// Asserted at capacities NEITHER caller ships — the Profiles row
/// pips pass a fixed 4/3 and a Monitors card passes whatever its
/// geometry measured — because a rule extracted to be shared has
/// to be right at the inputs its next caller will bring, not only
/// at the two that exist. The callers keep their own suites for
/// what they draw.
@Suite("Overflow split")
struct OverflowSplitTests {
    private func shown(
        _ count: Int,
        _ capacity: Int,
        _ marker: Int
    ) -> Int {
        OverflowSplit.shown(
            of: count,
            fitting: capacity,
            withMarker: marker
        )
    }

    /// Everything that fits is drawn and no marker appears — the
    /// boundary included, which is the case a naive "reserve the
    /// marker whenever anything might overflow" gets wrong.
    @Test("a run that fits draws whole, with no marker")
    func fittingRunDrawsWhole() {
        for count in 0...7 {
            #expect(shown(count, 7, 6) == count)
        }
    }

    /// The clause that made this worth sharing: the marker takes
    /// a slot, so a run that would leave exactly one item hidden
    /// gives up one more rather than spending a slot to say "+1".
    ///
    /// Swept over a range of capacities AND over every marker
    /// capacity each admits, since the surfaces that use this
    /// pass different ones — a rule proven only at 4/3 is a rule
    /// proven for one caller.
    ///
    /// Sweeping the marker capacity is what makes this test
    /// reach the rule at all, and the first cut did not. Where
    /// the marker costs a slot (`markerCapacity == capacity - 1`,
    /// which is what the Profiles pips pass) the property holds
    /// by the EARLY RETURN — a run of exactly `capacity + 1`
    /// draws `capacity` and hides… two, because the marker took
    /// one — and the `- 1` correction inside is never reached.
    /// It is reached only when the marker costs nothing
    /// (`markerCapacity == capacity`), which a Monitors card
    /// measures whenever the `+n` happens to fit the same row.
    /// So the correction is live code with one real caller, and
    /// the sweep has to include that shape or it guards the
    /// clause it was written for by never executing it.
    @Test("the marker never claims to hide exactly one")
    func neverHidesExactlyOne() {
        for capacity in 1...12 {
            for marker in 0...capacity {
                for count in 0...40 {
                    let drawn = shown(count, capacity, marker)
                    #expect(
                        count - drawn != 1,
                        Comment(
                            rawValue:
                                "capacity \(capacity), marker "
                                + "\(marker), count \(count) "
                                + "hid exactly one"
                        )
                    )
                }
            }
        }
    }

    /// Known splits at a capacity neither caller ships, written
    /// out rather than recomputed: capacity 6, marker slot costs
    /// one (marker capacity 5) — the Profiles pips' shape.
    @Test("the split is the expected pair at capacity 6")
    func knownSplitsAtSix() {
        #expect(shown(6, 6, 5) == 6)
        // The marker's own slot is what makes 7 hide two.
        #expect(shown(7, 6, 5) == 5)
        #expect(shown(8, 6, 5) == 5)
        #expect(shown(20, 6, 5) == 5)
    }

    /// The same capacity where the marker costs NO slot — a
    /// Monitors card whose `+n` fits the row it measured. This
    /// is the only shape that reaches the `- 1` correction: at
    /// 7 items the run would draw 6 and hide exactly one, so it
    /// gives up one more.
    @Test("a free marker slot still never hides exactly one")
    func knownSplitsWithAFreeMarker() {
        #expect(shown(6, 6, 6) == 6)
        #expect(shown(7, 6, 6) == 5)
        #expect(shown(8, 6, 6) == 6)
    }

    /// A card at its floor has room for the marker or one item,
    /// not both — zero drawn is a real answer, and it must not
    /// go negative.
    @Test("a zero marker capacity draws nothing, never less")
    func zeroMarkerCapacityIsFloored() {
        #expect(shown(5, 1, 0) == 0)
        #expect(shown(2, 1, 0) == 0)
    }

    /// A nonsense count from a hand-edited file must not produce
    /// a negative run for a `ForEach` range to trap on.
    @Test("a negative count draws nothing")
    func negativeCountDrawsNothing() {
        #expect(shown(-1, 4, 3) == 0)
        #expect(shown(-99, 4, 3) == 0)
    }
}
