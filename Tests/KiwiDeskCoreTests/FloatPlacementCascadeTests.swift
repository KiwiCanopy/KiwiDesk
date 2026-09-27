import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The centred placement's cascade (#1708), pure: a spot is taken
/// by a float sharing its centre or piling with it by #1177's own
/// containment test, either way round.
@Suite("Float placement cascade")
struct FloatPlacementCascadeTests {
    private let region = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let step = FloatPlacement.cascadeStep

    @Test("a free spot keeps the centred frame")
    func freeSpotStays() {
        let frame = CGRect(x: 400, y: 200, width: 800, height: 600)
        let others = [CGRect(x: 0, y: 0, width: 300, height: 300)]
        #expect(
            FloatPlacement.cascaded(frame, avoiding: others, in: region)
                == frame
        )
    }

    @Test("a taken spot steps down and right, past every taker")
    func takenSpotSteps() {
        let frame = CGRect(x: 400, y: 200, width: 800, height: 600)
        let others = [frame, frame.offsetBy(dx: step, dy: step)]
        #expect(
            FloatPlacement.cascaded(frame, avoiding: others, in: region)
                == frame.offsetBy(dx: step * 2, dy: step * 2)
        )
    }

    /// A step off the shared centre still lies inside the larger
    /// window: only a step that leaves it is free.
    @Test("a smaller window centred inside a larger one steps out")
    func concentricStepsOut() {
        let frame = CGRect(x: 500, y: 250, width: 600, height: 500)
        let larger = CGRect(x: 400, y: 200, width: 800, height: 600)
        let placed = FloatPlacement.cascaded(
            frame,
            avoiding: [larger],
            in: region
        )
        #expect(placed.minX - frame.minX > step)
        #expect(placed.minX - frame.minX == placed.minY - frame.minY)
        #expect(!FloatGather.isPiled(placed, among: [larger]))
    }

    @Test("a larger window stepped over a smaller one steps out")
    func coveringStepsOut() {
        let frame = CGRect(x: 400, y: 200, width: 800, height: 600)
        let smaller = CGRect(x: 520, y: 220, width: 300, height: 200)
        let placed = FloatPlacement.cascaded(
            frame,
            avoiding: [smaller],
            in: region
        )
        #expect(placed != frame)
        #expect(!FloatGather.isPiled(smaller, among: [placed]))
    }

    /// Neither contains the other, so only the shared centre can
    /// call the spot taken.
    @Test("a crossing window sharing the centre is taken")
    func sharedCentreIsTaken() {
        let frame = CGRect(x: 400, y: 300, width: 800, height: 400)
        let crossing = CGRect(x: 600, y: 100, width: 400, height: 800)
        #expect(
            FloatPlacement.cascaded(frame, avoiding: [crossing], in: region)
                == frame.offsetBy(dx: step, dy: step)
        )
    }

    /// A float too large to walk out of must not switch the
    /// cascade off: the shared centre still steps the new window.
    @Test("a float too large to leave still lets a centre step")
    func largeFloatKeepsTheCentreStep() {
        let frame = CGRect(x: 400, y: 170, width: 800, height: 660)
        // Maximised: every step inside the region stays inside it.
        let big = region
        let placed = FloatPlacement.cascaded(
            frame,
            avoiding: [big, frame],
            in: region
        )
        #expect(placed == frame.offsetBy(dx: step, dy: step))
    }

    @Test("a step off the region prices the pile at the centre")
    func stepOffRegionStays() {
        let frame = CGRect(x: 400, y: 380, width: 800, height: 600)
        #expect(
            FloatPlacement.cascaded(frame, avoiding: [frame], in: region)
                == frame
        )
    }
}
