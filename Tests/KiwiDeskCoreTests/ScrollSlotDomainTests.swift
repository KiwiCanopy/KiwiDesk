import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Every arm of the scrolling slot resize decision (#1057),
/// tested on the pure domain — the writer is plumbing, so the
/// cap logic is pinned here where each case is a plain input
/// table. The engine-level wirings are
/// `ScrollingFixedSpanCueTests` / `ScrollingSlotCeilingTests`.
@Suite("Scroll slot resize decision (#1057)")
struct ScrollSlotDomainTests {
    private func decide(
        delta: CGFloat,
        stored: CGFloat,
        drawnArea: CGFloat = 1160,
        drawnFocused: CGFloat? = nil,
        configured: CGFloat? = nil,
        globalMin: CGFloat = 300,
        appMin: CGFloat? = nil,
        appMax: CGFloat? = nil
    ) -> ScrollSlotDomain.Outcome {
        ScrollSlotDomain.decide(
            delta: delta,
            stored: stored,
            drawnArea: drawnArea,
            drawnFocused: drawnFocused
                ?? min(stored, drawnArea),
            configured: configured ?? stored,
            globalMin: globalMin,
            appMin: appMin,
            appMax: appMax
        )
    }

    @Test("A grow at the window's maximum refuses in place")
    func growAtMaximumRefusesInPlace() {
        // The owner's scenario (2026-08-28): slot far below
        // the pinned window's span — the press must not walk
        // the store up through the neighbors; it says "max
        // reached" on the FIRST press and moves nothing.
        let outcome = decide(
            delta: 50,
            stored: 300,
            drawnFocused: 825,
            appMin: 825,
            appMax: 825
        )
        #expect(outcome.write == nil)
        #expect(outcome.refusal == .ownMaximum)
    }

    @Test("A grow on an oversize store refuses wordlessly")
    func growOnOversizeStoreIsSilent() {
        // #966's config protection: nothing to grow into, and
        // rewriting the configured 3000 downward on a GROW is
        // the destruction the ceiling ruled out.
        let outcome = decide(delta: 400, stored: 3000)
        #expect(outcome.write == nil)
        #expect(outcome.refusal == nil)
    }

    @Test("A grow reaches a window pinned above the store")
    func growReachesAPinnedWindow() {
        // Min-pinned at 400 with the slot at 300: the window
        // CAN grow, so the press measures from ITS span — one
        // press, visible growth — instead of walking the store
        // up to 400 first.
        let outcome = decide(
            delta: 50,
            stored: 300,
            drawnFocused: 400,
            appMin: 400
        )
        #expect(outcome.write == 450)
        #expect(outcome.refusal == nil)
    }

    @Test("A grow into the app ceiling clamps and cues")
    func growIntoTheCeilingCues() {
        let outcome = decide(
            delta: 400,
            stored: 600,
            appMax: 715
        )
        #expect(outcome.write == 715)
        #expect(outcome.refusal == .ownMaximum)
    }

    @Test("A viewport-truncated grow writes and stays wordless")
    func viewportTruncationStaysSilent() {
        let outcome = decide(delta: 4000, stored: 600)
        #expect(outcome.write == 1160)
        #expect(outcome.refusal == nil)
    }

    @Test("The pill survives a maximum past the viewport")
    func maximumPastTheViewportStillPills() {
        // The at-maximum arm's OWN weight (guard-prover,
        // 2026-08-28): with the window's maximum at or past
        // the drawn area, the fallthrough's app-vs-viewport
        // discrimination goes wordless — only the refusal arm
        // keeps the pill for a window that genuinely cannot
        // grow.
        let outcome = decide(
            delta: 50,
            stored: 1100,
            drawnFocused: 1200,
            appMin: 1200,
            appMax: 1200
        )
        #expect(outcome.write == nil)
        #expect(outcome.refusal == .ownMaximum)
    }

    @Test("A shrink into the floor writes the part that fits")
    func shrinkIntoTheFloorWritesAndCues() {
        // The clamp-then-write arm (code review, 2026-08-28):
        // a press that reaches below the global floor from
        // ABOVE it still applies the part that fits, and cues
        // — refuse-in-place is only for a window already AT a
        // bound.
        let outcome = decide(delta: -350, stored: 600)
        #expect(outcome.write == 300)
        #expect(outcome.refusal == .ownMinimum)
    }

    @Test("The tolerance band above the minimum still refuses")
    func toleranceBandAboveMinimumRefuses() {
        // The at-minimum arm's OWN weight (guard-prover,
        // 2026-08-28): one point above the app floor sits
        // inside the match tolerance — the arm refuses there,
        // where the fallthrough's global floor (below the app
        // floor) would have written straight through it.
        let outcome = decide(
            delta: -50,
            stored: 501,
            drawnFocused: 501,
            appMin: 500
        )
        #expect(outcome.write == nil)
        #expect(outcome.refusal == .ownMinimum)
    }

    @Test("A shrink at the window's minimum refuses in place")
    func shrinkAtMinimumRefusesInPlace() {
        // Both the below-span store (never-raise) and the
        // above-span store (never shrink the neighbors from a
        // window that cannot follow) — one rule.
        let below = decide(
            delta: -50,
            stored: 300,
            drawnFocused: 825,
            appMin: 825
        )
        #expect(below.write == nil)
        #expect(below.refusal == .ownMinimum)
        let above = decide(
            delta: -50,
            stored: 850,
            drawnFocused: 825,
            appMin: 825
        )
        #expect(above.write == nil)
        #expect(above.refusal == .ownMinimum)
    }

    @Test("A shrink on an oversize store starts from the drawn")
    func shrinkFromDrawn() {
        // #1057's filed case: the first press has visible
        // effect, and the store is rewritten only now — the
        // moment the user deliberately resizes here.
        let outcome = decide(delta: -400, stored: 3000)
        #expect(outcome.write == 760)
        #expect(outcome.refusal == nil)
    }

    @Test("A shrink at the global floor refuses with the cue")
    func shrinkAtGlobalFloorCues() {
        let outcome = decide(delta: -50, stored: 300)
        #expect(outcome.write == nil)
        #expect(outcome.refusal == .ownMinimum)
    }

    @Test("The floor wins a narrower-display contradiction")
    func floorWinsTheContradiction() {
        // Display narrower than min_window_size: the drawn
        // area sits UNDER the floor, and the press must refuse
        // rather than write a value below it.
        let outcome = decide(
            delta: -400,
            stored: 300,
            drawnArea: 180
        )
        #expect(outcome.write == nil)
        #expect(outcome.refusal == .ownMinimum)
    }

    @Test("Ordinary presses pass through unclamped")
    func ordinaryPressesPassThrough() {
        #expect(
            decide(delta: 50, stored: 600).write == 650
        )
        #expect(
            decide(delta: -50, stored: 600).write == 550
        )
        #expect(decide(delta: -50, stored: 600).refusal == nil)
    }
}
