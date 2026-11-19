import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A long swipe's steps count finger travel in mm, the first one
/// included (#1873 ▸ Ruling 2026-11-16, #3482): the finger reading
/// sets the budget only, the point deltas keep the axis and each
/// pad axis's way, the latch is the floor only where points count,
/// and a touch counts in the one unit it fixed.
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

    /// A meter past its first step, the reading at `start`.
    private func latched(at start: TouchTravel.Reading) -> ScrollStepMeter {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        let origin = TouchTravel.Reading(
            sum: CGVector(dx: start.sum.dx - length, dy: start.sum.dy),
            source: start.source
        )
        _ = meter.feed(event(.began), reading: origin)
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

    /// The pad's own axes are never flipped: the sign follows
    /// Natural scrolling's one flip, carried on the event (#3505).
    @Test("the sign follows Natural scrolling")
    func signFollowsNatural() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began), reading: on(0))
        // Fingers right on the pad, content reversed by Natural off.
        var right = event(.changed, dx: -40)
        right.reversed = true
        #expect(meter.feed(right, reading: on(12)) == -1)
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

    /// The first step costs one length of finger travel from the
    /// touch's first reading, however far the points ran (#3482).
    @Test("the first step costs one length")
    func firstStepCostsALength() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began), reading: on(0))
        #expect(
            meter.feed(event(.changed, dx: 200), reading: on(length - 1))
                == 0
        )
        #expect(meter.feed(event(.changed, dx: 1), reading: on(length)) == 1)
        #expect(
            meter.feed(event(.changed, dx: 1), reading: on(2 * length - 1))
                == 0
        )
        #expect(
            meter.feed(event(.changed, dx: 1), reading: on(2 * length))
                == 1
        )
    }

    /// No point floor in mm: a length of finger travel steps however
    /// few points it took, since a point threshold makes a fast
    /// swipe step sooner (#3482, owner 2026-11-19).
    @Test("a first step in mm owes no point floor")
    func noPointFloor() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began), reading: on(0))
        #expect(meter.feed(event(.changed, dx: 4), reading: on(length)) == 1)
    }

    /// A reading whose pad carries no two fingers — a Magic Mouse
    /// beside a pad, whose reading is the pad's — steps at the
    /// latch and counts points.
    @Test("a scroll the pad did not make counts points")
    func untouchedPadCountsPoints() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        let stride = length * ScrollStepMeter.pointsPerMM
        let still = TouchTravel.Reading(
            sum: CGVector(dx: 7, dy: 0),
            source: 1,
            touching: false
        )
        _ = meter.feed(event(.began), reading: still)
        #expect(meter.feed(event(.changed, dx: 20), reading: still) == 0)
        #expect(meter.feed(event(.changed, dx: 5), reading: still) == 1)
        #expect(
            meter.feed(event(.changed, dx: stride - 1), reading: still) == 0
        )
        #expect(meter.feed(event(.changed, dx: 1), reading: still) == 1)
    }

    /// A fast flick whose points outrun the reading by far more than
    /// a points stride waits for the reading and counts mm, never
    /// switching to points.
    @Test("a fast flick ahead of its reading stays in mm")
    func flickStaysInMM() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began), reading: on(0))
        #expect(meter.feed(event(.changed, dx: 400), reading: on(0)) == 0)
        #expect(meter.feed(event(.changed, dx: 400), reading: on(0)) == 0)
        #expect(meter.feed(event(.changed, dx: 5), reading: on(length)) == 1)
        #expect(
            meter.feed(event(.changed, dx: 500), reading: on(2 * length - 1))
                == 0
        )
    }

    /// A reading lost before the first step waits: a touch that
    /// fixed mm never counts points after it.
    @Test("a reading lost before the first step waits")
    func lostBeforeTheFirstWaits() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began), reading: on(0))
        #expect(meter.feed(event(.changed, dx: 30), reading: on(4)) == 0)
        #expect(meter.feed(event(.changed, dx: 500), reading: nil) == 0)
        #expect(meter.feed(event(.changed, dx: 1), reading: on(length)) == 1)
    }

    /// A reading at the begin and none after: the touch steps at
    /// the latch's floor and counts points.
    @Test("no reading after the begin steps at the floor")
    func noReadingAtTheFloor() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began), reading: on(0))
        #expect(meter.feed(event(.changed, dx: 30), reading: nil) == 1)
    }

    /// A new source before the first step re-bases with no move.
    @Test("a new source before the first step re-bases")
    func sourceChangeBeforeTheFirst() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began), reading: on(0))
        #expect(meter.feed(event(.changed, dx: 5), reading: on(4)) == 0)
        // A jump of several lengths between the two sums.
        let fresh = TouchTravel.Reading(
            sum: CGVector(dx: 40, dy: 0),
            source: 2
        )
        #expect(meter.feed(event(.changed, dx: 25), reading: fresh) == 0)
        let moved = TouchTravel.Reading(
            sum: CGVector(dx: 40 + length - 4, dy: 0),
            source: 2
        )
        #expect(meter.feed(event(.changed, dx: 1), reading: moved) == 1)
    }

    /// With Long swipes off the one step fires at the latch, a
    /// reading or not.
    @Test("without long swipes the latch fires the one step")
    func shortSwipeIsTheLatch() {
        var meter = ScrollStepMeter(longSwipes: false, length: length)
        _ = meter.feed(event(.began), reading: on(0))
        #expect(meter.feed(event(.changed, dx: 30), reading: on(0)) == 1)
        #expect(meter.feed(event(.changed, dx: 500), reading: on(90)) == 0)
    }

    /// A new touch fixes its unit again at its own latch.
    @Test("each touch fixes its unit at its latch")
    func unitPerTouch() {
        var meter = ScrollStepMeter(longSwipes: true, length: length)
        _ = meter.feed(event(.began))
        #expect(meter.feed(event(.changed, dx: 30)) == 1)
        _ = meter.feed(event(.ended))
        _ = meter.feed(event(.began), reading: on(0))
        #expect(meter.feed(event(.changed, dx: 30), reading: on(length)) == 1)
        #expect(
            meter.feed(event(.changed, dx: 1), reading: on(2 * length)) == 1
        )
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
