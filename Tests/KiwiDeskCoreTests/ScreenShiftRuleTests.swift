import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The #2756 plan's rules, each on a desk where it decides: no move
/// takes a third screen's last free corner, crossings outrank the
/// main screen, and a corner two screens reach names the one it
/// lands on most. Frames are global CG points, y down.
@Suite("Screen shift rules (#2756)")
struct ScreenShiftRuleTests {
    private func screen(
        _ id: String,
        _ x: CGFloat,
        _ y: CGFloat,
        _ w: CGFloat,
        _ h: CGFloat,
        main: Bool = false
    ) -> ArrangedScreen {
        ArrangedScreen(
            id: id,
            name: id,
            frame: CGRect(x: x, y: y, width: w, height: h),
            isMain: main
        )
    }

    /// A middle screen between two taller ones, the right one with
    /// a still taller screen of its own to its right: raising the
    /// right one would box it in, the middle reaching below it.
    private var chain: [ArrangedScreen] {
        [
            screen("left", -1000, 0, 1000, 1200, main: true),
            screen("middle", 0, 0, 1000, 1000),
            screen("right", 1000, 0, 1000, 1100),
            screen("far", 2000, 0, 1000, 1500),
        ]
    }

    @Test("No move takes a screen's last free corner")
    func freeCornerKept() {
        let right = chain[2]
        #expect(ScreenShiftPlan.hasFreeCorner(right, in: chain))
        #expect(
            ScreenShiftPlan.shortest(
                moving: "right",
                along: CGVector(dx: 0, dy: -1),
                freeing: chain[1],
                in: chain
            ) == nil
        )
    }

    @Test("One crossing on the main screen beats two elsewhere")
    func crossingsBeforeMain() throws {
        // Raising the main left screen changes one crossing.
        // Lowering the middle and raising the right are shorter and
        // move no main screen, but change two crossings each.
        let desk = [
            screen("left", -1000, 0, 1000, 1200, main: true),
            screen("middle", 0, 0, 1000, 1000),
            screen("right", 1000, 0, 1000, 1100),
            screen("far", 2000, 0, 1000, 500),
        ]
        let shifts = try #require(ScreenShiftPlan.offer(desk)).shifts
        #expect(shifts.map(\.screen) == ["left"])
        #expect(shifts.first?.delta == CGVector(dx: 0, dy: -248))
    }

    @Test("A corner two screens reach names the larger cover")
    func largerCoverNamed() throws {
        // The right corner reaches the tall screen beside it and,
        // by a sliver, a small screen below.
        let desk = [
            screen("left", -1000, 0, 1000, 1200),
            screen("middle", 0, 0, 1000, 1000),
            screen("right", 1000, 0, 1000, 1500),
            screen("below", 500, 1000, 600, 100),
        ]
        let verdict = try #require(ScreenShiftPlan.boxedIn(desk).first)
        #expect(verdict.screen == "middle")
        #expect(verdict.cause == .corners(left: "left", right: "right"))
    }
}
