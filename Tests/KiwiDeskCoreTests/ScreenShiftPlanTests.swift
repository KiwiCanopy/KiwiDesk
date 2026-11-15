import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A boxed-in screen and the move the offer proposes (#2756):
/// fewest changed crossings, then a screen other than the main
/// one, then the smallest distance. Frames are global CG points,
/// y growing down.
@Suite("Screen shift plan (#2756)")
struct ScreenShiftPlanTests {
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

    /// The preview's desk: a laptop between two taller screens.
    private var threeScreens: [ArrangedScreen] {
        [
            screen("lg", -2560, -100, 2560, 1440),
            screen("laptop", 0, 0, 1728, 1117, main: true),
            screen("dell", 1728, -159, 2560, 1440),
        ]
    }

    @Test("The owner's two-screen desk has no boxed-in screen")
    func ownersDesk() {
        let desk = [
            screen("laptop", 0, 0, 1728, 1117, main: true),
            screen("dell", 1728, -159, 2560, 1440),
        ]
        #expect(ScreenShiftPlan.boxedIn(desk).isEmpty)
        #expect(ScreenShiftPlan.offer(desk) == nil)
    }

    @Test("A laptop between two taller screens is boxed in")
    func boxedBetweenTwo() throws {
        let verdicts = ScreenShiftPlan.boxedIn(threeScreens)
        let verdict = try #require(verdicts.first)
        #expect(verdicts.count == 1)
        #expect(verdict.screen == "laptop")
        #expect(verdict.cause == .corners(left: "lg", right: "dell"))
        // The DELL reaches less far below, so the stash parks
        // bottom-right and the windows show on it.
        #expect(verdict.landsOn == "dell")
    }

    /// The offer's moves, which must be one.
    private func onlyShift(
        _ screens: [ArrangedScreen]
    ) throws -> ScreenShift {
        let shifts = try #require(ScreenShiftPlan.offer(screens)).shifts
        #expect(shifts.count == 1)
        return try #require(shifts.first)
    }

    /// The arrangement after an offer's moves.
    private func applied(
        _ shifts: [ScreenShift],
        to screens: [ArrangedScreen]
    ) -> [ArrangedScreen] {
        screens.map { screen in
            shifts.first { $0.screen == screen.id }.map {
                screen.moved(by: $0.delta)
            } ?? screen
        }
    }

    @Test("Raising one neighbour beats lowering the boxed screen")
    func neighbourMoves() throws {
        let shift = try onlyShift(threeScreens)
        // 164 pt the DELL reaches below the laptop, plus the 48 pt
        // a parked window's top sits above the bottom edge.
        #expect(shift.screen == "dell")
        #expect(shift.delta == CGVector(dx: 0, dy: -212))
        #expect(shift.crossings.map(\.screen) == ["laptop"])
    }

    @Test("The shift frees the corner and no other screen's")
    func shiftLeavesEveryCorner() throws {
        let shift = try onlyShift(threeScreens)
        let after = applied([shift], to: threeScreens)
        #expect(ScreenShiftPlan.boxedIn(after).isEmpty)
        for screen in after {
            #expect(ScreenShiftPlan.hasFreeCorner(screen, in: after))
        }
    }

    @Test("A wider screen below slides sideways")
    func belowBothSlides() throws {
        let desk = [
            screen("laptop", 0, 0, 1728, 1117, main: true),
            screen("wide", -600, 1117, 3440, 1440),
        ]
        let verdict = try #require(ScreenShiftPlan.boxedIn(desk).first)
        #expect(verdict.cause == .belowBoth("wide"))
        let shift = try onlyShift(desk)
        // Its left edge moves just past the laptop's bottom-left
        // corner, the nearer of the two.
        #expect(shift.screen == "wide")
        #expect(shift.delta == CGVector(dx: 601, dy: 0))
        #expect(shift.crossings.map(\.screen) == ["laptop"])
    }

    @Test("At an equal count and distance a non-main screen moves")
    func mainMovesLast() throws {
        let desk = [
            screen("left", -1000, 0, 1000, 1500, main: true),
            screen("middle", 0, 0, 1000, 1000),
            screen("right", 1000, 0, 1000, 1500),
        ]
        let shift = try onlyShift(desk)
        #expect(shift.screen == "right")
        #expect(shift.delta == CGVector(dx: 0, dy: -548))
    }

    @Test("Moving two crossings loses to moving one")
    func fewestCrossingsWin() throws {
        // Lowering the middle is shortest but changes two
        // crossings; raising the left changes one but moves the
        // main screen; raising the right changes one, further.
        let desk = [
            screen("left", -1000, 0, 1000, 1100, main: true),
            screen("middle", 0, 0, 1000, 1000),
            screen("right", 1000, -200, 1000, 1400),
        ]
        let lowered = try #require(
            ScreenShiftPlan.shortest(
                moving: "middle",
                along: CGVector(dx: 0, dy: 1),
                freeing: desk[1],
                in: desk
            )
        )
        let raised = try #require(
            ScreenShiftPlan.shortest(
                moving: "right",
                along: CGVector(dx: 0, dy: -1),
                freeing: desk[1],
                in: desk
            )
        )
        #expect(abs(lowered.delta.dy) < abs(raised.delta.dy))
        let shift = try onlyShift(desk)
        #expect(shift.screen == "right")
        #expect(shift.crossings.map(\.screen) == ["middle"])
    }

    @Test("Two boxed-in screens get one offer freeing both")
    func oneOfferForTwo() throws {
        let desk = [
            screen("studio", -5120, -400, 2560, 1840),
            screen("wide", -2560, 0, 2560, 1117),
            screen("laptop", 0, 0, 1728, 1117, main: true),
            screen("dell", 1728, -159, 2560, 1440),
        ]
        let offer = try #require(ScreenShiftPlan.offer(desk))
        #expect(offer.boxed.map(\.screen) == ["wide", "laptop"])
        #expect(!offer.shifts.isEmpty)
        let after = applied(offer.shifts, to: desk)
        #expect(ScreenShiftPlan.boxedIn(after).isEmpty)
        #expect(
            ScreenShiftPlan.touchingPairs(desk)
                .isSubset(of: ScreenShiftPlan.touchingPairs(after))
        )
    }

    @Test("A corner-to-corner meeting is no crossing")
    func cornerIsNoCrossing() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(
            !ScreenShiftPlan.touches(
                a,
                CGRect(x: 100, y: 100, width: 100, height: 100)
            )
        )
        #expect(
            ScreenShiftPlan.touches(
                a,
                CGRect(x: 100, y: 50, width: 100, height: 100)
            )
        )
    }
}
