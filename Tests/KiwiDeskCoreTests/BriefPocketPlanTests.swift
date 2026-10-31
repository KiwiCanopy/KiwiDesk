import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The brief pocket's placement and timeline (#2680), pure.
@Suite("Brief pocket plan")
struct BriefPocketPlanTests {
    private let side = BriefPocketPlan.side

    @Test(
        "into: the plate flies first, the pocket nods as it lands"
    )
    func intoTimeline() {
        let line = BriefPocketPlan.timeline(.into, flight: 0.3)
        #expect(line.flightBegin == 0)
        #expect(line.nodBegin == line.flightEnd)
        #expect(line.liftBegin > line.nodBegin)
        #expect(line.handOff == line.end)
    }

    @Test("out of the pocket: the pocket nods, then the plate grows out")
    func outTimeline() {
        let line = BriefPocketPlan.timeline(.outOf, flight: 0.3)
        #expect(line.nodBegin == line.flightBegin)
        #expect(line.flightBegin == BriefPocketPlan.fadeIn)
        #expect(line.end >= line.flightEnd)
        #expect(line.handOff == line.flightEnd)
        #expect(line.handOff < line.end)
    }

    @Test("the plate leaves the window and ends at the mark's size")
    func plateEnds() {
        let window = CGRect(x: 100, y: 100, width: 600, height: 400)
        let pocket = CGRect(x: 800, y: 580, width: side, height: side)
        let line = BriefPocketPlan.timeline(.into, flight: 0.3)
        let start = BriefPocketPlan.plateFrame(
            at: 0,
            direction: .into,
            window: window,
            pocket: pocket,
            timeline: line
        )
        #expect(start == window)
        let end = BriefPocketPlan.plateFrame(
            at: line.flightEnd,
            direction: .into,
            window: window,
            pocket: pocket,
            timeline: line
        )
        #expect(end.width == BriefPocketPlan.markSide)
        #expect(end.midX == pocket.midX && end.midY == pocket.midY)
        let out = BriefPocketPlan.timeline(.outOf, flight: 0.3)
        let landed = BriefPocketPlan.plateFrame(
            at: out.flightEnd,
            direction: .outOf,
            window: window,
            pocket: pocket,
            timeline: out
        )
        #expect(landed == window)
    }

    @Test("the plate fades where it meets the pocket")
    func plateOpacity() {
        let line = BriefPocketPlan.timeline(.into, flight: 0.3)
        #expect(
            BriefPocketPlan.plateOpacity(
                at: 0,
                direction: .into,
                timeline: line
            )
                == 1
        )
        #expect(
            BriefPocketPlan.plateOpacity(
                at: line.end,
                direction: .into,
                timeline: line
            ) == 0
        )
        let out = BriefPocketPlan.timeline(.outOf, flight: 0.3)
        #expect(
            BriefPocketPlan.plateOpacity(
                at: 0,
                direction: .outOf,
                timeline: out
            )
                == 0
        )
    }

    @Test("the pocket fades in and out and only swells during its nod")
    func pocketMotion() {
        let line = BriefPocketPlan.timeline(.into, flight: 0.3)
        #expect(BriefPocketPlan.pocketOpacity(at: 0, timeline: line) == 0)
        #expect(
            BriefPocketPlan.pocketOpacity(at: line.nodBegin, timeline: line)
                == 1
        )
        #expect(
            BriefPocketPlan.pocketOpacity(at: line.end + 0.01, timeline: line)
                == 0
        )
        let pocket = CGRect(x: 0, y: 0, width: side, height: side)
        #expect(
            BriefPocketPlan.pocketFrame(pocket, at: 0, timeline: line)
                == pocket
        )
        let swollen = BriefPocketPlan.pocketFrame(
            pocket,
            at: line.nodBegin + BriefPocketPlan.nod / 2,
            timeline: line
        )
        #expect(swollen.width > side)
        #expect(swollen.midX == pocket.midX)
    }

    @Test("the flight follows the window duration, bounded")
    func flight() {
        #expect(BriefPocketPlan.flight(durationMS: 150) == 0.3)
        #expect(BriefPocketPlan.flight(durationMS: 50) == 0.2)
        #expect(BriefPocketPlan.flight(durationMS: 1000) == 0.8)
    }
}
