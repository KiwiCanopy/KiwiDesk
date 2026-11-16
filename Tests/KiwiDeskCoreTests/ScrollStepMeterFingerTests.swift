import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A long swipe's steps past the latch count finger travel in mm
/// (#1873 ▸ Ruling 2026-11-16): the finger reading sets the budget
/// only, the point deltas keep the axis and sign, and a touch
/// counts in the one unit the latch fixed.
@Suite("Scroll step meter, finger travel")
struct ScrollStepMeterFingerTests {
    private let length = 10.0

    /// A reading of one pad's sum.
    private func on(_ dx: Double, _ dy: Double = 0) -> TouchTravel.Reading {
        TouchTravel.Reading(sum: CGVector(dx: dx, dy: dy), source: 1)
    }

    private func event(
        _ kind: ScrollGestureEvent.Kind,
        dx: Double = 0,
        dy: Double = 0
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: [.control, .option],
            kind: kind,
            input: .trackpad,
            delta: CGVector(dx: dx, dy: dy),
            momentum: false,
            location: .zero,
            time: 0
        )
    }

    /// A meter past its latch, the reading at `start`.
    private func latched(at start: TouchTravel.Reading) -> ScrollStepMeter {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began), reading: start)
        #expect(meter.feed(event(.changed, dx: 30), reading: start) == 1)
        return meter
    }

    /// The same finger travel steps the same, whatever the point
    /// deltas say: a fast swipe's large deltas buy no extra step.
    @Test("finger mm, not point deltas, set the spacing")
    func fingerSetsTheBudget() {
        var slow = latched(at: on(0))
        var fast = latched(at: on(0))
        var slowSteps = 0
        var fastSteps = 0
        for index in 1...5 {
            let finger = on(Double(index) * 4)
            slowSteps += slow.feed(event(.changed, dx: 5), reading: finger)
            fastSteps += fast.feed(event(.changed, dx: 60), reading: finger)
        }
        // 20 mm of finger travel at 10 mm a step.
        #expect(slowSteps == 2)
        #expect(fastSteps == 2)
    }

    /// The pad's own axes are never flipped: the sign is the point
    /// delta's, which has had Natural scrolling's one flip.
    @Test("the sign is the point delta's")
    func signFollowsThePoints() {
        var meter = latched(at: on(0))
        // Fingers right on the pad, content reversed by Natural off.
        let steps = meter.feed(
            event(.changed, dx: -40),
            reading: on(12)
        )
        #expect(steps == -1)
    }

    /// The axis is the point travel's: a vertical finger reading
    /// beside horizontal points steps nothing vertical.
    @Test("the axis is the point travel's")
    func axisFollowsThePoints() {
        var meter = latched(at: on(0))
        let steps = meter.feed(
            event(.changed, dx: 20, dy: 1),
            reading: on(2, 30)
        )
        #expect(steps == 0)
        #expect(meter.firedHorizontal == true)
    }

    /// A reading lost mid-touch stops the steps; it never switches
    /// the touch to points.
    @Test("a reading lost mid-touch steps nothing")
    func lostReadingSteps() {
        var meter = latched(at: on(0))
        #expect(meter.feed(event(.changed, dx: 500), reading: nil) == 0)
    }

    /// No reading at the latch: the touch counts points, at the
    /// fallback rate, a later reading included.
    @Test("no reading at the latch counts points")
    func noReadingCountsPoints() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began))
        #expect(meter.feed(event(.changed, dx: 30)) == 1)
        let stride = length * ScrollStepMeter.pointsPerMM
        #expect(
            meter.feed(
                event(.changed, dx: stride - 1),
                reading: on(100)
            ) == 0
        )
        #expect(meter.feed(event(.changed, dx: 1)) == 1)
    }

    /// The mm origin is the latch's reading, never the touch's
    /// begin: finger travel before the latch buys no later step.
    @Test("the origin is the latch's reading")
    func originIsTheLatch() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began), reading: on(0))
        #expect(meter.feed(event(.changed, dx: 30), reading: on(20)) == 1)
        #expect(
            meter.feed(event(.changed, dx: 1), reading: on(20 + length - 1))
                == 0
        )
    }

    /// A new touch fixes its unit again at its own latch.
    @Test("each touch fixes its unit at its latch")
    func unitPerTouch() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began))
        #expect(meter.feed(event(.changed, dx: 30)) == 1)
        _ = meter.feed(event(.ended))
        _ = meter.feed(event(.began), reading: on(0))
        #expect(meter.feed(event(.changed, dx: 30), reading: on(0)) == 1)
        #expect(meter.feed(event(.changed, dx: 1), reading: on(length)) == 1)
    }

    /// A reading from another source — a rebuilt reader whose sum
    /// starts over, another pad — re-bases with no move, never a
    /// burst of steps from the jump.
    @Test("a new source re-bases without a step")
    func sourceChangeRebases() {
        var meter = latched(at: on(500))
        let fresh = TouchTravel.Reading(sum: .zero, source: 2)
        #expect(meter.feed(event(.changed, dx: 5), reading: fresh) == 0)
        let moved = TouchTravel.Reading(
            sum: CGVector(dx: length, dy: 0),
            source: 2
        )
        #expect(meter.feed(event(.changed, dx: 5), reading: moved) == 1)
    }

    /// After a step the axis is the point travel's since that step,
    /// in either unit, so a step's remainder never outvotes a turn:
    /// mostly-vertical travel after a sideways step steps nothing
    /// sideways.
    @Test("a turn after a step is decided afresh, in points too")
    func turnAfterAStep() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        let stride = length * ScrollStepMeter.pointsPerMM
        _ = meter.feed(event(.began))
        #expect(meter.feed(event(.changed, dx: 30)) == 1)
        #expect(meter.feed(event(.changed, dx: stride * 1.95)) == 1)
        #expect(
            meter.feed(event(.changed, dx: stride * 0.06, dy: stride / 2))
                == 0
        )
        #expect(meter.feed(event(.changed, dy: stride / 2)) == 1)
        #expect(meter.firedHorizontal == false)
    }
}
