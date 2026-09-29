import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// How many windows a scroll moves (#1656, rulings 2026-09-29):
/// a swipe or a notch is one by default; `by_length` counts
/// finger travel; the glide never counts.
@Suite("Scroll step meter")
struct ScrollStepMeterTests {
    private func event(
        _ kind: ScrollGestureEvent.Kind,
        dx: Double = 0,
        dy: Double = 0,
        input: ScrollGestureEvent.Input = .trackpad,
        momentum: Bool = false
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: [.control, .option],
            kind: kind,
            input: input,
            delta: CGVector(dx: dx, dy: dy),
            momentum: momentum,
            location: .zero
        )
    }

    private let stride = 60.0

    /// Long swipes on, past the first window: what follows is
    /// the further travel the distance counts.
    private func byLength() -> ScrollStepMeter {
        var meter = ScrollStepMeter(longSwipes: true, distance: stride)
        _ = meter.feed(event(.began))
        _ = meter.feed(event(.changed, dx: firstStep))
        return meter
    }

    /// Travel that fires the first window: the latch's threshold.
    private let firstStep = 30.0

    @Test("by default a swipe is one step, however long")
    func oneStepPerSwipe() {
        var meter = ScrollStepMeter(longSwipes: false, distance: stride)
        _ = meter.feed(event(.began))
        let steps = (0..<10).map { _ in
            meter.feed(event(.changed, dx: stride))
        }
        #expect(steps.reduce(0, +) == 1)
        _ = meter.feed(event(.ended))
        _ = meter.feed(event(.began))
        #expect(meter.feed(event(.changed, dx: -stride)) == -1)
    }

    @Test("long swipes, a stride of travel is one step and the rest carries")
    func strideCarries() {
        var meter = byLength()
        #expect(meter.feed(event(.changed, dx: stride * 0.6)) == 0)
        #expect(meter.feed(event(.changed, dx: stride * 0.6)) == 1)
        #expect(meter.feed(event(.changed, dx: stride * 0.7)) == 0)
        #expect(meter.feed(event(.changed, dx: stride * 0.2)) == 1)
    }

    @Test("long swipes, reversing unwinds the carried travel")
    func reverseUnwinds() {
        var meter = byLength()
        #expect(meter.feed(event(.changed, dx: stride * 0.9)) == 0)
        #expect(meter.feed(event(.changed, dx: -stride * 0.9)) == 0)
        #expect(meter.feed(event(.changed, dx: -stride)) == -1)
    }

    @Test("long swipes, several strides in one event are several steps")
    func manyAtOnce() {
        var meter = byLength()
        #expect(meter.feed(event(.changed, dy: -stride * 3.5)) == -3)
    }

    @Test("long swipes: the first window comes early, then one per distance")
    func firstEarlyThenDistance() {
        var meter = ScrollStepMeter(longSwipes: true, distance: 200)
        _ = meter.feed(event(.began))
        #expect(meter.feed(event(.changed, dx: firstStep)) == 1)
        #expect(meter.feed(event(.changed, dx: 199)) == 0)
        #expect(meter.feed(event(.changed, dx: 1)) == 1)
    }

    @Test("the glide never counts, either stepping")
    func momentumIgnored() {
        for longSwipes in [false, true] {
            var meter = ScrollStepMeter(
                longSwipes: longSwipes,
                distance: stride
            )
            _ = meter.feed(event(.began))
            #expect(
                meter.feed(event(.changed, dx: stride * 9, momentum: true))
                    == 0
            )
        }
    }

    @Test("a wheel notch is one step, either stepping")
    func wheelNotch() {
        for longSwipes in [false, true] {
            var meter = ScrollStepMeter(
                longSwipes: longSwipes,
                distance: stride
            )
            _ = meter.feed(event(.began, input: .wheel))
            #expect(meter.feed(event(.changed, dy: 1, input: .wheel)) == 1)
            #expect(
                meter.feed(event(.changed, dy: -stride * 5, input: .wheel))
                    == -1
            )
        }
    }

    @Test("long swipes: a new gesture starts over at the first window")
    func gestureResets() {
        var meter = byLength()
        _ = meter.feed(event(.changed, dx: stride * 0.9))
        _ = meter.feed(event(.ended))
        _ = meter.feed(event(.began))
        #expect(meter.feed(event(.changed, dx: 5)) == 0)
        #expect(meter.feed(event(.changed, dx: firstStep)) == 1)
    }

    @Test("the larger axis carries the step")
    func dominantAxis() {
        var meter = byLength()
        #expect(
            meter.feed(event(.changed, dx: stride / 2, dy: -stride))
                == -1
        )
    }
}
