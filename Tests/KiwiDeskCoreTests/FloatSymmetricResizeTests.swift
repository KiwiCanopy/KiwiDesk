import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A floating keyboard resize is symmetric, with pinned edges
/// (#1091, owner ruling 2026-08-29).
///
/// The numbers are the owner's own reversibility table, on a
/// 1728-wide screen at ±100. They are pinned here rather than
/// paraphrased because the table IS the ruling: every steady
/// state must round-trip, and the one state that does not — the
/// step into contact with a boundary — is an accepted residue
/// that has to stay bounded at half a step.
///
/// The screen is stated in the fixture rather than inherited,
/// the way every geometry fixture must pin its display (#531).
@Suite("Float symmetric resize (#1091)")
struct FloatSymmetricResizeTests {
    /// The float region: a 1728x1117 screen with no bars.
    private let region = CGRect(
        x: 0,
        y: 0,
        width: 1728,
        height: 1117
    )
    private let step: CGFloat = 100
    private let minSize: CGFloat = 50

    private func grow(_ frame: CGRect) -> FloatResize.Outcome {
        FloatResize.resized(
            frame,
            horizontal: true,
            delta: step,
            minSize: minSize,
            bounds: region
        )
    }

    private func shrink(_ frame: CGRect) -> FloatResize.Outcome {
        FloatResize.resized(
            frame,
            horizontal: true,
            delta: -step,
            minSize: minSize,
            bounds: region
        )
    }

    private func rect(_ x: CGFloat, _ w: CGFloat) -> CGRect {
        CGRect(x: x, y: 100, width: w, height: 400)
    }

    @Test("Free on both sides: the delta splits evenly")
    func middleSplitsEvenly() {
        let grown = grow(rect(800, 400))
        #expect(grown.frame == rect(750, 500))
        #expect(grown.refusal == nil)
        // ...and back.
        #expect(shrink(grown.frame).frame == rect(800, 400))
    }

    @Test("A pinned edge sends the whole delta the other way")
    func pinnedEdgeSendsTheWholeDelta() {
        // Right edge exactly on 1728.
        let grown = grow(rect(1328, 400))
        #expect(grown.frame == rect(1228, 500))
        #expect(grown.refusal == nil)
        // The pin holds on the way back too, which is the half
        // of the rule easiest to drop: shrink pinned on the
        // right must come entirely off the LEFT, or the window
        // walks away from the edge it was parked against.
        #expect(shrink(grown.frame).frame == rect(1328, 400))
    }

    @Test("The left edge pins the same way")
    func leftEdgePins() {
        let grown = grow(rect(0, 400))
        #expect(grown.frame == rect(0, 500))
        #expect(shrink(grown.frame).frame == rect(0, 400))
    }

    @Test("Both edges pinned: a grow refuses, a shrink does not")
    func bothPinned() {
        let wall = rect(0, 1728)
        let grown = grow(wall)
        #expect(grown.refusal == .blocked)
        #expect(grown.frame == wall)
        // A shrink always has somewhere to go — refusing it
        // would strand a wall-to-wall window at a size it could
        // never leave.
        let shrunk = shrink(wall)
        #expect(shrunk.refusal == nil)
        #expect(shrunk.frame == rect(50, 1628))
    }

    @Test("A refused grow is the ONLY thing that reports one")
    func onlyABlockedGrowRefuses() {
        // The refusal drives a user-visible cue, so a false
        // positive pills a resize that worked. Every arm that
        // delivered its whole ask must report nil — including
        // the PINNED grow, which moves only one edge but still
        // travels the full delta.
        #expect(grow(rect(800, 400)).refusal == nil)
        #expect(grow(rect(1328, 400)).refusal == nil)
        #expect(shrink(rect(0, 1728)).refusal == nil)
        #expect(shrink(rect(800, 400)).refusal == nil)
    }

    @Test("A PARTLY blocked grow reports truncation, and moves")
    func partialGrowIsTruncated() {
        // The hole review found: 28 pt of room against an asked
        // 100 moved the window and said nothing, while the
        // shrink arm three lines away in the command cues on
        // exactly this — #933's "landing ON the limit is already
        // a refusal of part of the request", which had never
        // been applied to the grow end.
        // Truncation needs the TOTAL room to fall short of the
        // ask, not merely one edge to be pinned: the spill
        // means a pinned edge still delivers the whole delta as
        // long as the other side can absorb it. So the case is a
        // window nearly filling the region — flush left, 40 pt
        // of room right, asked 100.
        let grown = grow(rect(0, 1688))
        #expect(grown.refusal == .truncated)
        // Truncated is not blocked: it still moved, by the 40 it
        // had.
        #expect(grown.frame == rect(0, 1728))
        // And the merely-pinned grow is NOT truncated, which is
        // the distinction the cue rests on.
        #expect(grow(rect(1300, 400)).refusal == nil)
    }

    @Test("The step into contact spills, and costs half a step")
    func contactResidueIsBounded() {
        // The accepted residue, pinned so it stays a RULING and
        // stays BOUNDED. 28 pt of room on the right: the grow
        // gives that side its 28 and spills the remaining 22
        // leftward, which pins the right edge.
        let grown = grow(rect(1300, 400))
        #expect(grown.frame == rect(1228, 500))
        // The following shrink now comes entirely off the left,
        // landing 28 pt right of the start — half a step is the
        // ceiling, and this is what must not grow.
        let back = shrink(grown.frame).frame
        #expect(back == rect(1328, 400))
        #expect(back.minX - 1300 == 28)
        // The CEILING, swept rather than asserted at one
        // fixture. The single `<= step / 2` clause beside the
        // `== 28` above was implied by it and could not fail
        // (code review, 2026-08-29) — so it carried the "half a
        // step is the ceiling" claim with a literal. Every
        // offset that puts the window into contact on this press
        // must stay inside the bound.
        for offset in stride(
            from: CGFloat(1229),
            through: 1328,
            by: 1
        ) {
            let start = rect(offset, 400)
            let round = shrink(grow(start).frame).frame
            #expect(round.minX - offset <= step / 2)
            #expect(round.minX - offset >= 0)
        }
    }

    @Test("A grow never exceeds the region, from either side")
    func aGrowNeverLeavesTheRegion() {
        // The under-the-bars defect in its general form: before
        // #1091 nothing bounded a float's SIZE at all, so a grow
        // ran past the region and the bar clamp — which only
        // pushes, never resizes — left it overflowing.
        //
        // Walked from BOTH sides of centre (guard-prover,
        // 2026-08-29). A single walk starting left of centre
        // drives the low edge into its pin first, so an overflow
        // confined to the HIGH edge left this green — the guard
        // fired every time on the side that happened to saturate
        // first, and never on the other.
        for start in [rect(600, 400), rect(900, 400)] {
            var frame = start
            for _ in 0..<40 {
                frame = grow(frame).frame
            }
            #expect(frame.minX >= region.minX)
            #expect(frame.maxX <= region.maxX)
            #expect(frame.width <= region.width)
        }
    }

    @Test("The y axis pins exactly as the x axis does")
    func verticalAxisPinsToo() {
        // Six of this suite's cases read `horizontal: true`, so
        // moving the vertical boundary out of reach left them all
        // green and the y pinning was held only by two suites in
        // unrelated subsystems (guard-prover, 2026-08-29). The
        // axis is a parameter, not a second implementation — but
        // "it is the same code" is exactly the claim a guard is
        // for.
        let tall = CGRect(x: 100, y: 717, width: 400, height: 400)
        // Bottom edge on 1117, the region's own maxY: pinned, so
        // the whole delta goes upward.
        let grown = FloatResize.resized(
            tall,
            horizontal: false,
            delta: step,
            minSize: minSize,
            bounds: region
        )
        #expect(grown.frame.minY == 617)
        #expect(grown.frame.height == 500)
        // And the pin holds on the way back.
        let back = FloatResize.resized(
            grown.frame,
            horizontal: false,
            delta: -step,
            minSize: minSize,
            bounds: region
        )
        #expect(back.frame == tall)
    }

    @Test("A y grow with both edges pinned refuses too")
    func verticalBothPinnedRefuses() {
        let wall = CGRect(x: 100, y: 0, width: 400, height: 1117)
        let grown = FloatResize.resized(
            wall,
            horizontal: false,
            delta: step,
            minSize: minSize,
            bounds: region
        )
        #expect(grown.refusal == .blocked)
        #expect(grown.frame == wall)
    }

    @Test("A bar-carved region pins at the bar, not the screen")
    func barsMoveTheBoundary() {
        // Two bars, opposite edges, of different depths — the
        // arrangement the fold has to survive: a space can show
        // one bar or two, on any edge.
        var carved = AppBarGeometry.regionClear(
            region,
            of: CGRect(x: 0, y: 0, width: 1728, height: 40),
            edge: .top
        )
        carved = AppBarGeometry.regionClear(
            carved,
            of: CGRect(x: 1628, y: 0, width: 100, height: 1117),
            edge: .right
        )
        #expect(carved == CGRect(x: 0, y: 40, width: 1628, height: 1077))
        // A float whose right edge sits on the carved boundary
        // is pinned there, 100 pt short of the screen edge.
        let grown = FloatResize.resized(
            rect(1228, 400),
            horizontal: true,
            delta: step,
            minSize: minSize,
            bounds: carved
        )
        #expect(grown.frame == rect(1128, 500))
    }

    @Test("Two strips on one edge leave the deeper carve")
    func deeperStripWins() {
        // Monotonicity: the fold needs no ordering rule, so both
        // orders must land on the deeper strip's carve.
        let shallow = CGRect(x: 0, y: 0, width: 1728, height: 30)
        let deep = CGRect(x: 0, y: 0, width: 1728, height: 70)
        let a = AppBarGeometry.regionClear(
            AppBarGeometry.regionClear(
                region,
                of: shallow,
                edge: .top
            ),
            of: deep,
            edge: .top
        )
        let b = AppBarGeometry.regionClear(
            AppBarGeometry.regionClear(region, of: deep, edge: .top),
            of: shallow,
            edge: .top
        )
        #expect(a == b)
        #expect(a.minY == 70)
    }
}
