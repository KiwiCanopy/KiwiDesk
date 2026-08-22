import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The per-share weight step and the two-sided split domain
/// (#933): per-index minimums, the refusal outcome, and the
/// margin that keeps a clamped-at-minimum write strictly inside
/// the layout's cascade check.
@Suite("Weight step & split domain outcomes (#933)")
struct WeightStepOutcomeTests {
    @Test("A shrink clamps at the stepped share's OWN minimum")
    func shrinkClampsAtOwnFloor() {
        let outcome = StackLayout.weightStep(
            weights: [1, 1],
            at: 0,
            delta: -600,
            span: 1000,
            minSizes: [400, 100]
        )
        #expect(outcome.hitOwnMinimum)
        #expect(outcome.blockedByOther == nil)
        // The rendered share stays at least its own minimum.
        let total = outcome.value + 1
        let rendered = 1000 * outcome.value / total
        #expect(rendered >= 400)
        #expect(rendered < 420)
    }

    @Test("A grow is capped by the TIGHTEST other share's minimum")
    func growBlockedByTightestOther() {
        // Two equal shares at 600 pt each; the other one's
        // learned floor is 500, so the grow truncates where it
        // would push the neighbor below 500 — not at the global
        // 300 floor the single-min form would have used.
        let outcome = StackLayout.weightStep(
            weights: [1, 1],
            at: 0,
            delta: 300,
            span: 1200,
            minSizes: [300, 500]
        )
        #expect(outcome.blockedByOther == 1)
        #expect(!outcome.hitOwnMinimum)
        // Truncated, not refused outright — and the blocking
        // share keeps its own minimum.
        #expect(outcome.value > 1)
        let total = outcome.value + 1
        let rendered = 1200 * 1 / total
        #expect(rendered >= 500)
    }

    @Test("A grow against a neighbor already under its floor is refused")
    func growRefusedByUnderFloorNeighbor() {
        // The middle share renders at 480 pt, under its learned
        // 500 floor: any grow of another share is refused
        // outright, and the middle index is named — not the
        // roomier third share.
        let outcome = StackLayout.weightStep(
            weights: [0.5, 1, 1],
            at: 0,
            delta: 300,
            span: 1200,
            minSizes: [300, 500, 300]
        )
        #expect(outcome.blockedByOther == 1)
        #expect(outcome.value == 0.5)
    }

    @Test("An unblocked step reports no refusal")
    func unblockedStepIsQuiet() {
        let outcome = StackLayout.weightStep(
            weights: [1, 1],
            at: 0,
            delta: 40,
            span: 1200,
            minSizes: [300, 300]
        )
        #expect(outcome.blockedByOther == nil)
        #expect(!outcome.hitOwnMinimum)
        #expect(outcome.value > 1)
    }

    @Test("The uniform wrapper matches the per-index form")
    func uniformWrapperMatches() {
        let old = StackLayout.weightStep(
            weights: [1, 2, 1],
            at: 1,
            delta: -200,
            span: 1400,
            minSize: 300
        )
        let new = StackLayout.weightStep(
            weights: [1, 2, 1],
            at: 1,
            delta: -200,
            span: 1400,
            minSizes: [300, 300, 300]
        )
        #expect(old == new.value)
    }

    @Test("A min-clamped write clears the cascade check")
    func marginClearsTheCascadeCheck() {
        // The clamp's fixed point and `maxColumnTotal` sit at
        // exact equality without the margin — float noise alone
        // could then tip a clamped write into the pile (#925's
        // residue). Strict inequality is the margin working.
        let span = 1184.0
        let outcome = StackLayout.weightStep(
            weights: [1, 1],
            at: 0,
            delta: -900,
            span: span,
            minSizes: [300, 300]
        )
        let total = outcome.value + 1
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: min(outcome.value, 1),
            span: span,
            minSize: 300
        )
        #expect(total < limit)
    }

    @Test("Two-sided ratio range carries each side's own minimum")
    func twoSidedRange() {
        let range = SplitDomain.effectiveRatioRange(
            available: 1000,
            minLow: 200,
            minHigh: 300
        )
        #expect(range == 0.2...0.7)
        #expect(
            SplitDomain.effectiveRatioRange(
                available: 450,
                minLow: 200,
                minHigh: 300
            ) == nil
        )
        // The symmetric form is the two-sided one with equal
        // minimums.
        #expect(
            SplitDomain.effectiveRatioRange(
                available: 1000,
                minSize: 250
            )
                == SplitDomain.effectiveRatioRange(
                    available: 1000,
                    minLow: 250,
                    minHigh: 250
                )
        )
    }

    @Test("Two-sided capped write reports truncation")
    func twoSidedCappedWrite() {
        let clamped = SplitDomain.cappedRatioWrite(
            0.05,
            base: 0.5,
            available: 1000,
            minLow: 200,
            minHigh: 300
        )
        #expect(clamped.value == 0.2)
        #expect(clamped.clamped)
        let free = SplitDomain.cappedRatioWrite(
            0.45,
            base: 0.5,
            available: 1000,
            minLow: 200,
            minHigh: 300
        )
        #expect(free.value == 0.45)
        #expect(!free.clamped)
        // The nil-range span stays uncapped and unreported —
        // there is no visible bound to stop at.
        let unsplittable = SplitDomain.cappedRatioWrite(
            0.05,
            base: 0.5,
            available: 100,
            minLow: 200,
            minHigh: 300
        )
        #expect(unsplittable.value == 0.05)
        #expect(!unsplittable.clamped)
    }
}
