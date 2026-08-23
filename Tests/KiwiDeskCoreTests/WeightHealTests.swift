import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure session-weight heal math (#944):
/// `StackLayout.healedWeights` — when a heal fires, what it
/// shaves, and when a pile is honest and stays.
@Suite("Session weight heal math (#944)")
struct WeightHealTests {

    @Test("a feasible group heals nothing")
    func feasibleGroupIsUntouched() {
        // total 3 against limit 1·1200/300 = 4.
        #expect(
            StackLayout.healedWeights(
                weights: [1, 1, 1],
                span: 1200,
                minSize: 300
            ) == nil
        )
    }

    @Test("a value between the margined target and the raw check stays")
    func marginBandIsLegal() {
        // The clamps write at most the MARGINED target; the
        // layout checks the RAW limit. A stored total between
        // the two renders fine, and shaving it would rewrite a
        // legal weight — limit here is 4.0, so 3.999 stands.
        #expect(
            StackLayout.healedWeights(
                weights: [1, 1, 1.999],
                span: 1200,
                minSize: 300
            ) == nil
        )
    }

    @Test("degenerate inputs heal nothing")
    func degenerateInputsAreNil() {
        #expect(
            StackLayout.healedWeights(
                weights: [10],
                span: 1200,
                minSize: 300
            ) == nil
        )
        #expect(
            StackLayout.healedWeights(
                weights: [10, 1],
                span: 0,
                minSize: 300
            ) == nil
        )
        #expect(
            StackLayout.healedWeights(
                weights: [10, 1],
                span: 1200,
                minSize: 0
            ) == nil
        )
    }

    @Test("too many members for the span is honest physics")
    func infeasibleCountStaysNil() {
        // Five members over 1200 pt at 300 pt minimum cannot fit
        // at ANY weights — that pile belongs to the overflow
        // folds, and a heal that fired here would rewrite state
        // without preventing it.
        #expect(
            StackLayout.healedWeights(
                weights: [1, 1, 1, 1, 1],
                span: 1200,
                minSize: 300
            ) == nil
        )
    }

    @Test("the #944 measured weights heal to a tiling total")
    func measuredCollapseHeals() throws {
        // Owner QA 2026-08-22: {10, 2.279, 1} on a ~1700 pt
        // screen — total 13.28 against a cascade limit of ~5.4,
        // every window piled.
        let weights = [10.0, 2.279, 1.0]
        let span = 1640.0
        let healed = try #require(
            StackLayout.healedWeights(
                weights: weights,
                span: span,
                minSize: 300
            )
        )
        // The healed total passes the RAW cascade check — the
        // layouts' own pile trigger — with the margin to spare.
        let smallest = try #require(healed.min())
        #expect(
            healed.reduce(0, +)
                <= StackLayout.maxColumnTotal(
                    smallestWeight: smallest,
                    span: span,
                    minSize: 300
                )
        )
        // It lands the smallest share exactly at the margined
        // minimum: total == smallest · span / (min + margin).
        let target = StackLayout.maxColumnTotal(
            smallestWeight: smallest,
            span: span,
            minSize: 300 + StackLayout.minSizeMargin
        )
        #expect(abs(healed.reduce(0, +) - target) < 0.0001)
        // The smallest weight is never shaved.
        #expect(healed[2] == 1.0)
    }

    @Test("the waterline shaves only the extremes")
    func waterlineSpansOnlyTheExtremes() throws {
        // Two extremes over a span where ~5.46 total fits: the
        // waterline caps both at one shared value above the
        // small weights, which survive untouched.
        let healed = try #require(
            StackLayout.healedWeights(
                weights: [10, 8, 1, 1],
                span: 1640,
                minSize: 300
            )
        )
        #expect(healed[2] == 1)
        #expect(healed[3] == 1)
        #expect(healed[0] == healed[1])
        #expect(healed[0] < 10)
        // Relative order survives: nothing shaved below a
        // weight it was above.
        #expect(healed[0] >= healed[2])
    }

    @Test("the spans subtract each axis's OWN gaps")
    func spansSubtractTheirOwnAxisGaps() {
        // Deliberately asymmetric gaps: under the symmetric
        // defaults an axis→gap swap in `acrossSpan`/`alongSpan`
        // is numerically invisible to every consumer suite
        // (guard-prover, round 2) — this pin is what reds it.
        let gaps = Gaps(
            outer: Gaps.Outer(
                top: 1,
                bottom: 2,
                left: 4,
                right: 8
            ),
            inner: Gaps.Inner(horizontal: 16, vertical: 32)
        )
        // Vertical tracks (columns): across = width, minus the
        // left/right outer pair and the HORIZONTAL inner gap
        // per boundary; along = height, minus top/bottom and
        // the VERTICAL inner gap.
        #expect(
            TrackLayout.acrossSpan(
                region: 1000,
                gaps: gaps,
                vertical: true,
                count: 3
            ) == 1000 - 12 - 32
        )
        #expect(
            TrackLayout.alongSpan(
                region: 1000,
                gaps: gaps,
                vertical: true,
                count: 3
            ) == 1000 - 3 - 64
        )
        // Horizontal tracks (rows) swap both pairs.
        #expect(
            TrackLayout.acrossSpan(
                region: 1000,
                gaps: gaps,
                vertical: false,
                count: 2
            ) == 1000 - 3 - 32
        )
        #expect(
            TrackLayout.alongSpan(
                region: 1000,
                gaps: gaps,
                vertical: false,
                count: 2
            ) == 1000 - 12 - 16
        )
    }

    @Test("the cap only lowers, and never below the smallest")
    func capOnlyLowersAndNeverBelowSmallest() throws {
        // The real per-index domain claim — the first draft
        // asserted `contains(v) || v >= weightFloor`, which
        // reduces to `v >= 0.05` and cannot fail for any
        // reachable output (guard-prover, round 1). A healed
        // value never exceeds its own input (so it stays inside
        // the store range the clamps enforced at write time)
        // and never drops below the group's smallest weight.
        let weights = [10.0, 10, 0.1]
        let healed = try #require(
            StackLayout.healedWeights(
                weights: weights,
                span: 1640,
                minSize: 300
            )
        )
        let smallest = try #require(weights.min())
        for (weight, value) in zip(weights, healed) {
            #expect(value <= weight)
            #expect(value >= smallest)
        }
        // And the heal genuinely moved something, so the two
        // bounds above are exercised rather than trivially met
        // by an untouched array.
        #expect(healed != weights)
    }
}
