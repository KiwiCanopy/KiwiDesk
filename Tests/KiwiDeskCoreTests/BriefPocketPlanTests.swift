import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The brief pocket's placement and timeline (#2680), pure.
@Suite("Brief pocket plan")
struct BriefPocketPlanTests {
    private let region = CGRect(x: 0, y: 30, width: 1000, height: 600)
    private let side = BriefPocketPlan.side
    private let margin = BriefPocketPlan.margin

    @Test("each edge holds the pocket inside, a margin from it")
    func edges() {
        let bottom = BriefPocketPlan.pocketFrame(
            in: region,
            edge: .bottom,
            position: 50
        )
        #expect(bottom.maxY == region.maxY - margin)
        #expect(bottom.midX == region.midX)
        let top = BriefPocketPlan.pocketFrame(
            in: region,
            edge: .top,
            position: 50
        )
        #expect(top.minY == region.minY + margin)
        let left = BriefPocketPlan.pocketFrame(
            in: region,
            edge: .left,
            position: 50
        )
        #expect(left.minX == region.minX + margin)
        #expect(left.midY == region.midY)
        let right = BriefPocketPlan.pocketFrame(
            in: region,
            edge: .right,
            position: 50
        )
        #expect(right.maxX == region.maxX - margin)
        #expect(bottom.width == side && bottom.height == side)
    }

    @Test("position runs left to right and top to bottom")
    func positionAlongTheEdge() {
        let at25 = BriefPocketPlan.pocketFrame(
            in: region,
            edge: .bottom,
            position: 25
        )
        #expect(at25.midX == 250)
        let down = BriefPocketPlan.pocketFrame(
            in: region,
            edge: .right,
            position: 75
        )
        #expect(down.midY == region.minY + 450)
    }

    @Test("the ends keep the whole pocket inside the region")
    func endsClamp() {
        for position: CGFloat in [0, 100, -20, 400] {
            let frame = BriefPocketPlan.pocketFrame(
                in: region,
                edge: .top,
                position: position
            )
            #expect(frame.minX >= region.minX + margin)
            #expect(frame.maxX <= region.maxX - margin)
        }
    }

    @Test("a narrower region moves the pocket inward with it")
    func barRegion() {
        // A bar 40 pt deep on the bottom edge, cleared from the region.
        let clear = AppBarGeometry.regionClear(
            region,
            of: CGRect(x: 0, y: region.maxY - 40, width: 1000, height: 40),
            edge: .bottom
        )
        let frame = BriefPocketPlan.pocketFrame(
            in: clear,
            edge: .bottom,
            position: 82
        )
        #expect(frame.maxY == region.maxY - 40 - margin)
    }

    @Test(
        "into: the plate flies first, the pocket nods as it lands"
    )
    func intoTimeline() {
        let line = BriefPocketPlan.timeline(.into, flight: 0.3)
        #expect(line.flightBegin == 0)
        #expect(line.nodBegin == line.flightEnd)
        #expect(line.liftBegin > line.nodBegin)
    }

    @Test("out of the pocket: the pocket nods, then the plate grows out")
    func outTimeline() {
        let line = BriefPocketPlan.timeline(.outOf, flight: 0.3)
        #expect(line.nodBegin == line.flightBegin)
        #expect(line.flightBegin == BriefPocketPlan.fadeIn)
        #expect(line.end >= line.flightEnd)
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
