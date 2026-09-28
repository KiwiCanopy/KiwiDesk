import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// One step per scroll gesture (#1519): threshold, then a latch
/// held until the gesture ends.
@Suite("Scroll step latch")
struct ScrollStepLatchTests {
    private func event(
        _ kind: ScrollGestureEvent.Kind,
        dx: Double = 0,
        dy: Double = 0,
        input: ScrollGestureEvent.Input = .trackpad
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: [.control, .option],
            kind: kind,
            input: input,
            delta: CGVector(dx: dx, dy: dy),
            momentum: false,
            location: .zero
        )
    }

    @Test("a fling steps once, however far it travels")
    func oneStepPerGesture() {
        var latch = ScrollStepLatch()
        _ = latch.feed(event(.began))
        let steps = (0..<40).compactMap {
            _ in latch.feed(event(.changed, dx: 10))
        }
        #expect(steps == [1])
        _ = latch.feed(event(.ended))
        _ = latch.feed(event(.began))
        #expect(latch.feed(event(.changed, dx: -30)) == -1)
    }

    @Test("trackpad drift under the threshold does not step")
    func thresholdHolds() {
        var latch = ScrollStepLatch()
        _ = latch.feed(event(.began))
        let under = ScrollStepLatch.trackpadThreshold - 1
        #expect(latch.feed(event(.changed, dy: under)) == nil)
        #expect(latch.feed(event(.changed, dy: 1)) == 1)
    }

    @Test("a wheel steps on its first notch")
    func wheelStepsAtOnce() {
        var latch = ScrollStepLatch()
        _ = latch.feed(event(.began, input: .wheel))
        #expect(latch.feed(event(.changed, dy: -2, input: .wheel)) == -1)
    }

    @Test("the axis with the larger travel picks the way")
    func dominantAxis() {
        var latch = ScrollStepLatch()
        _ = latch.feed(event(.began))
        #expect(latch.feed(event(.changed, dx: -20, dy: 30)) == 1)
        _ = latch.feed(event(.ended))
        _ = latch.feed(event(.began))
        #expect(latch.feed(event(.changed, dx: -30, dy: 20)) == -1)
    }
}
