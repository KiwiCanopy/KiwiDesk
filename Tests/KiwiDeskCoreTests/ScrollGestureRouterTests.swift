import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// `ScrollGestureRouter` decides which scrolls the tap swallows
/// and what the owning consumer hears (#1656, #1519).
@Suite("Scroll gesture router")
struct ScrollGestureRouterTests {
    private static let pan: ScrollChord = [.control, .option]
    private static let step: ScrollChord = [.control, .option, .command]

    private func router() -> ScrollGestureRouter {
        var router = ScrollGestureRouter()
        router.chords = [Self.pan, Self.step]
        return router
    }

    private func sample(
        _ chord: ScrollChord,
        dy: Double = 0,
        _ phase: ScrollSample.Phase = .none,
        momentum: ScrollSample.Momentum = .none
    ) -> ScrollSample {
        ScrollSample(
            chord: chord,
            delta: CGVector(dx: 0, dy: dy),
            phase: phase,
            momentum: momentum
        )
    }

    @Test("a scroll without a bound chord passes untouched")
    func unboundPasses() {
        var router = router()
        for chord: ScrollChord in [[], [.control], [.option, .command]] {
            let routed = router.route(sample(chord, dy: 5), now: 0)
            #expect(!routed.consume)
            #expect(routed.events.isEmpty)
        }
        let swipe = router.route(sample([], .began), now: 0)
        #expect(!swipe.consume)
    }

    @Test("an empty chord in the set never owns a plain scroll")
    func emptyChordNeverOwns() {
        var router = ScrollGestureRouter()
        router.chords = [[], Self.pan]
        #expect(!router.route(sample([], dy: 5), now: 0).consume)
        #expect(!router.route(sample([], .began), now: 1).consume)
        #expect(!router.route(sample([], .mayBegin), now: 2).consume)
    }

    @Test("a chord matches exactly: ⌃⌥ never answers ⌃⌥⌘")
    func exactMatch() {
        var router = ScrollGestureRouter()
        router.chords = [Self.pan]
        let routed = router.route(sample(Self.step, dy: 5), now: 0)
        #expect(!routed.consume)
        let swipe = router.route(sample(Self.step, .began), now: 1)
        #expect(!swipe.consume)
        let touch = router.route(sample(Self.step, .mayBegin), now: 2)
        #expect(!touch.consume)
    }

    @Test("a trackpad gesture owns its momentum after the keys lift")
    func trackpadKeepsMomentum() {
        var router = router()
        let began = router.route(sample(Self.pan, .began), now: 0)
        #expect(began.consume)
        #expect(began.events.map(\.kind) == [.began])
        let moved = router.route(sample([], dy: 4, .changed), now: 0.01)
        #expect(moved.consume)
        #expect(moved.events.map(\.kind) == [.changed])
        #expect(moved.events.first?.chord == Self.pan)
        #expect(router.route(sample([], .ended), now: 0.02).consume)
        let glide = router.route(
            sample([], dy: 9, momentum: .began),
            now: 0.03
        )
        #expect(glide.consume)
        #expect(glide.events.first?.momentum == true)
        #expect(router.expire(now: 5).isEmpty)
        let done = router.route(sample([], momentum: .ended), now: 0.5)
        #expect(done.consume)
        #expect(done.events.map(\.kind) == [.ended])
    }

    @Test("a lift with no momentum ends at the grace deadline")
    func liftEndsAtGrace() {
        var router = router()
        _ = router.route(sample(Self.pan, .began), now: 0)
        _ = router.route(sample(Self.pan, .ended), now: 1)
        #expect(router.deadline == 1 + ScrollGestureRouter.momentumGrace)
        #expect(router.expire(now: 1.01).isEmpty)
        let ended = router.expire(now: 1.2)
        #expect(ended.map(\.kind) == [.ended])
        #expect(router.deadline == nil)
    }

    @Test("a gesture that began unchorded is never taken mid-flight")
    func neverStolenMidGesture() {
        var router = router()
        #expect(!router.route(sample([], .began), now: 0).consume)
        let late = router.route(sample(Self.pan, dy: 3, .changed), now: 0)
        #expect(!late.consume)
        let lateGlide = router.route(
            sample(Self.pan, dy: 3, momentum: .changed),
            now: 0.1
        )
        #expect(!lateGlide.consume)
    }

    @Test("a touch that never moves is owned but says nothing")
    func mayBeginCancelledIsSilent() {
        var router = router()
        let touch = router.route(sample(Self.pan, .mayBegin), now: 0)
        #expect(touch.consume)
        #expect(touch.events.isEmpty)
        let cancel = router.route(sample(Self.pan, .cancelled), now: 0)
        #expect(cancel.consume)
        #expect(cancel.events.isEmpty)
        // The cancel released the gesture: a stray change passes.
        let stray = router.route(sample([], dy: 2, .changed), now: 0.1)
        #expect(!stray.consume)
    }

    @Test("a touch that starts moving begins, and so later ends")
    func mayBeginThenChangedBegins() {
        var router = router()
        _ = router.route(sample(Self.pan, .mayBegin), now: 0)
        let moved = router.route(sample(Self.pan, dy: 3, .changed), now: 0)
        #expect(moved.events.map(\.kind) == [.began, .changed])
        let cancel = router.route(sample(Self.pan, .cancelled), now: 0.1)
        #expect(cancel.events.map(\.kind) == [.ended])
    }

    @Test("a plain gesture ends the chorded one still gliding, and passes")
    func plainGestureSupersedes() {
        var router = router()
        _ = router.route(sample(Self.pan, .began), now: 0)
        _ = router.route(sample(Self.pan, .ended), now: 0.1)
        _ = router.route(sample([], dy: 5, momentum: .began), now: 0.1)
        let plain = router.route(sample([], .began), now: 0.2)
        #expect(!plain.consume)
        #expect(plain.events.map(\.kind) == [.ended])
        let next = router.route(sample([], dy: 4, .changed), now: 0.3)
        #expect(!next.consume)
        #expect(next.events.isEmpty)
    }

    @Test("a wheel and a trackpad never share one gesture")
    func inputsNeverMix() {
        var router = router()
        _ = router.route(sample(Self.pan, .began), now: 0)
        let wheel = router.route(sample(Self.pan, dy: 10), now: 0.1)
        #expect(wheel.events.map(\.kind) == [.ended, .began, .changed])
        #expect(wheel.events.last?.input == .wheel)
        let glide = router.route(
            sample(Self.pan, dy: 3, momentum: .changed),
            now: 0.15
        )
        #expect(!glide.consume)
        #expect(glide.events.isEmpty)
    }

    @Test("a new gesture ends the one still gliding")
    func newGestureSupersedes() {
        var router = router()
        _ = router.route(sample(Self.pan, .began), now: 0)
        _ = router.route(sample(Self.pan, .ended), now: 0.1)
        _ = router.route(sample([], dy: 5, momentum: .began), now: 0.1)
        let next = router.route(sample(Self.step, .began), now: 0.2)
        #expect(next.events.map(\.kind) == [.ended, .began])
        #expect(next.events.map(\.chord) == [Self.pan, Self.step])
    }

    @Test("a touch passed through stays the app's once the chord is down")
    func passedTouchStaysPassed() {
        var router = router()
        #expect(!router.route(sample([], .mayBegin), now: 0).consume)
        let began = router.route(sample(Self.pan, dy: 2, .began), now: 0)
        #expect(!began.consume)
        #expect(began.events.isEmpty)
        #expect(!router.route(sample(Self.pan, .ended), now: 0.1).consume)
        // The next gesture is the chord's again.
        #expect(router.route(sample(Self.pan, .began), now: 0.5).consume)
    }

    @Test("a quick unchorded swipe leaves the next chorded one alone")
    func passingIsScopedToOneHandoff() {
        var router = router()
        // A plain swipe with no touch phase, its end lost.
        #expect(!router.route(sample([], .began), now: 0).consume)
        #expect(router.route(sample(Self.pan, .began), now: 1).consume)
        // A passed touch hands over one .began, then no more.
        var fresh = self.router()
        _ = fresh.route(sample([], .mayBegin), now: 0)
        #expect(!fresh.route(sample(Self.pan, .began), now: 0).consume)
        #expect(fresh.route(sample(Self.pan, .began), now: 1).consume)
    }

    @Test("the travel a .began carries is reported, not dropped")
    func beganTravelIsReported() {
        var router = router()
        let began = router.route(sample(Self.pan, dy: 6, .began), now: 0)
        #expect(began.events.map(\.kind) == [.began, .changed])
        #expect(began.events.last?.delta.dy == 6)
    }

    @Test("an expired gesture ends where it last was")
    func expiryKeepsLocation() {
        var router = router()
        var first = sample(Self.pan, dy: 10)
        first.location = CGPoint(x: 10, y: 10)
        var last = sample(Self.pan, dy: 10)
        last.location = CGPoint(x: 900, y: 40)
        _ = router.route(first, now: 0)
        _ = router.route(last, now: 0.1)
        #expect(router.expire(now: 5).first?.location == last.location)
    }

    @Test("a wheel burst ends at a pause")
    func wheelBurstEndsAtPause() {
        var router = router()
        let first = router.route(sample(Self.pan, dy: 10), now: 0)
        #expect(first.consume)
        #expect(first.events.map(\.kind) == [.began, .changed])
        #expect(first.events.map(\.input) == [.wheel, .wheel])
        #expect(first.events.first?.delta == .zero)
        let second = router.route(sample(Self.pan, dy: 10), now: 0.1)
        #expect(second.events.map(\.kind) == [.changed])
        #expect(router.deadline == 0.1 + ScrollGestureRouter.wheelPause)
        #expect(router.expire(now: 0.2).isEmpty)
        #expect(router.expire(now: 1).map(\.kind) == [.ended])
    }

    @Test("a wheel burst ends the moment its chord stops matching")
    func wheelReleaseEndsBurst() {
        var router = router()
        _ = router.route(sample(Self.pan, dy: 10), now: 0)
        let plain = router.route(sample([], dy: 10), now: 0.05)
        #expect(!plain.consume)
        #expect(plain.events.map(\.kind) == [.ended])
        let other = router.route(sample(Self.step, dy: 10), now: 0.06)
        #expect(other.consume)
        #expect(other.events.map(\.kind) == [.began, .changed])
        #expect(other.events.first?.chord == Self.step)
    }

    @Test("a gesture whose chord is unbound mid-flight is released")
    func unboundMidFlightReleases() {
        var router = router()
        _ = router.route(sample(Self.pan, .began), now: 0)
        router.chords = [Self.step]
        let next = router.route(sample([], dy: 3, .changed), now: 0.1)
        #expect(!next.consume)
        #expect(next.events.map(\.kind) == [.ended])
        let glide = router.route(
            sample([], dy: 3, momentum: .changed),
            now: 0.2
        )
        #expect(!glide.consume)
    }

    /// The spin guard reads the hand's spacing off these stamps,
    /// never the main actor's (#1519).
    @Test("every event carries the tap's clock")
    func stampsTheClock() {
        var router = router()
        let first = router.route(sample(Self.step, dy: -3), now: 4)
        #expect(first.events.map(\.time) == [4, 4])
        let next = router.route(sample(Self.step, dy: -3), now: 4.1)
        #expect(next.events.map(\.time) == [4.1])
        #expect(router.expire(now: 4.5).map(\.time) == [4.5])
    }

    @Test("orphan momentum and changes pass")
    func orphansPass() {
        var router = router()
        #expect(!router.route(sample(Self.pan, .changed), now: 0).consume)
        #expect(!router.route(sample(Self.pan, .ended), now: 0).consume)
        #expect(
            !router.route(
                sample(Self.pan, momentum: .changed),
                now: 0
            ).consume
        )
    }
}
