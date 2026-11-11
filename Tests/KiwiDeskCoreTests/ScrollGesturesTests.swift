import CoreGraphics
import Testing

@testable import KiwiDeskCore

private final class FakeTap: ScrollTapHandle {
    var chords: ScrollTapChords = []
    var deliver: ScrollGestureTap.Deliver?
    var stopped = false
    func setChords(_ chords: ScrollTapChords) { self.chords = chords }
    func stop() { stopped = true }
}

/// The tap's front (#1656, #1519): the machine tap exists only
/// while the core is started, the consumer is wired AND a chord
/// routes, and a routed event reaches it with its chord's route.
@MainActor
@Suite("Scroll gestures front")
struct ScrollGesturesTests {
    private static let pan: ScrollChord = [.control, .option]
    private static let step: ScrollChord = [.control, .option, .command]

    private func front() -> (ScrollGestures, () -> [FakeTap]) {
        let gestures = ScrollGestures()
        var made: [FakeTap] = []
        gestures.makeTap = { deliver in
            let tap = FakeTap()
            tap.deliver = deliver
            made.append(tap)
            return tap
        }
        gestures.onLog = { _ in }
        return (gestures, { made })
    }

    private static let panRoute = ScrollRoute(
        swipe: .family(.focus),
        wheel: .family(.walk)
    )
    private static let stepRoute = ScrollRoute(
        swipe: .family(.space),
        wheel: .family(.space)
    )

    private func settings(
        pan: ScrollChord? = ScrollGesturesTests.pan,
        step: ScrollChord? = ScrollGesturesTests.step,
        natural: Bool = true,
        naturalMouse: Bool = true
    ) -> ScrollGestureSettings {
        var routes: [ScrollChord: ScrollRoute] = [:]
        if let pan { routes[pan] = Self.panRoute }
        if let step { routes[step] = Self.stepRoute }
        return ScrollGestureSettings(
            routes: routes,
            naturalTrackpad: natural,
            naturalMouse: naturalMouse
        )
    }

    private func event(
        _ chord: ScrollChord,
        _ kind: ScrollGestureEvent.Kind,
        dx: Double = 0,
        dy: Double = 0
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: chord,
            kind: kind,
            input: .trackpad,
            delta: CGVector(dx: dx, dy: dy),
            momentum: false,
            location: CGPoint(x: 7, y: 9),
            time: 0
        )
    }

    @Test("no tap until started, wired and given a chord")
    func tapFollowsSettings() {
        let (gestures, made) = front()
        gestures.configure(settings(step: nil))
        gestures.start()
        #expect(made().isEmpty)
        gestures.setHandler { _, _ in }
        #expect(made().count == 1)
        #expect(made().first?.chords == [Self.pan])
        gestures.setHandler { _, _ in }
        gestures.configure(settings())
        #expect(made().count == 1)
        #expect(made().first?.chords == [Self.pan, Self.step])
        gestures.configure(settings(pan: nil, step: nil))
        #expect(made().first?.stopped == true)
        #expect(!gestures.isTapped)
    }

    @Test("stop tears the tap down and drops what was still queued")
    func stopTearsDown() {
        let (gestures, made) = front()
        var heard = 0
        gestures.setHandler { _, _ in heard += 1 }
        gestures.configure(settings(step: nil))
        gestures.start()
        gestures.stop()
        #expect(made().first?.stopped == true)
        #expect(!gestures.isTapped)
        gestures.receive([event(Self.pan, .began)])
        #expect(heard == 0)
    }

    @Test("a stop ends a gesture in flight")
    func stopEndsInFlight() {
        let (gestures, _) = front()
        var heard: [ScrollGestureEvent.Kind] = []
        gestures.setHandler { e, _ in heard.append(e.kind) }
        gestures.configure(settings())
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        gestures.stop()
        #expect(heard == [.began, .ended])
        gestures.start()
        gestures.receive([event(Self.pan, .changed)])
        #expect(heard == [.began, .ended])
    }

    @Test("a plain scroll can never be configured")
    func emptyChordRefused() {
        let (gestures, made) = front()
        gestures.setHandler { _, _ in }
        gestures.start()
        gestures.configure(settings(pan: [], step: nil))
        #expect(made().isEmpty)
        #expect(gestures.settings.routes.isEmpty)
    }

    /// A gesture keeps the route it began with; a change to its
    /// chord's route ends it, and its later events reach nothing.
    @Test("a changed route ends the gesture in flight")
    func changedRouteEnds() {
        let (gestures, _) = front()
        var heard: [(ScrollGestureEvent.Kind, ScrollRoute)] = []
        gestures.setHandler { heard.append(($0.kind, $1)) }
        gestures.configure(settings())
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        var swapped = settings(pan: nil)
        swapped = ScrollGestureSettings(
            routes: [Self.pan: Self.stepRoute],
            naturalTrackpad: true,
            naturalMouse: true
        )
        gestures.configure(swapped)
        gestures.receive([event(Self.pan, .changed, dx: 5)])
        #expect(heard.map(\.0) == [.began, .ended])
        #expect(heard.map(\.1) == [Self.panRoute, Self.panRoute])
    }

    @Test("re-applying the same settings keeps a live gesture")
    func sameSettingsKeepGesture() {
        let (gestures, _) = front()
        var heard: [ScrollGestureEvent.Kind] = []
        gestures.setHandler { e, _ in heard.append(e.kind) }
        gestures.configure(settings())
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        gestures.configure(settings())
        gestures.configure(settings(natural: false))
        gestures.receive([event(Self.pan, .changed)])
        #expect(heard == [.began, .changed])
    }

    @Test("Natural scrolling off flips the delta, once, here")
    func naturalScrollingFlips() {
        let (gestures, _) = front()
        var deltas: [CGVector] = []
        gestures.setHandler { e, _ in deltas.append(e.delta) }
        gestures.configure(settings())
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        gestures.receive([event(Self.pan, .changed, dx: 5, dy: 3)])
        gestures.configure(settings(natural: false))
        gestures.receive([event(Self.pan, .changed, dx: 5, dy: 3)])
        #expect(
            deltas == [
                .zero, CGVector(dx: 5, dy: 3), CGVector(dx: -5, dy: -3),
            ]
        )
    }

    @Test("a reversed event still carries the hand's own motion")
    func reversedKeepsTheHand() {
        let (gestures, _) = front()
        var hands: [CGVector] = []
        gestures.setHandler { e, _ in hands.append(e.hand) }
        gestures.configure(settings(natural: false))
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        gestures.receive([event(Self.pan, .changed, dx: 5, dy: 3)])
        #expect(hands.last == CGVector(dx: 5, dy: 3))
    }

    @Test("each input takes its own Natural scrolling")
    func naturalScrollingPerInput() {
        let (gestures, _) = front()
        var deltas: [CGFloat] = []
        gestures.setHandler { e, _ in deltas.append(e.delta.dx) }
        gestures.configure(settings(naturalMouse: false))
        gestures.start()
        var wheel = event(Self.pan, .began)
        wheel.input = .wheel
        gestures.receive([wheel])
        wheel.kind = .changed
        wheel.delta = CGVector(dx: 5, dy: 0)
        gestures.receive([wheel])
        var ended = wheel
        ended.kind = .ended
        ended.delta = .zero
        gestures.receive([ended])
        gestures.receive([event(Self.pan, .began)])
        gestures.receive([event(Self.pan, .changed, dx: 5)])
        #expect(deltas == [0, -5, 0, 0, 5])
    }

    @Test("what the tap routes reaches the consumer on the main queue")
    func tapDeliveryReachesConsumer() async {
        let (gestures, made) = front()
        var heard: [ScrollGestureEvent.Kind] = []
        gestures.setHandler { e, _ in heard.append(e.kind) }
        gestures.configure(settings())
        gestures.start()
        made().first?.deliver?([event(Self.pan, .began)])
        await withCheckedContinuation { done in
            DispatchQueue.main.async { done.resume() }
        }
        #expect(heard == [.began])
    }

    @Test("the pointer tracker's start and stop carry the tap")
    func trackerCarriesTheTap() {
        let tracker = MouseTracker()
        var made = 0
        tracker.scroll.makeTap = { _ in
            made += 1
            return FakeTap()
        }
        tracker.scroll.onLog = { _ in }
        tracker.scroll.host = .unset
        tracker.scroll.setHandler { _, _ in }
        tracker.scroll.configure(settings())
        #expect(made == 0)
        tracker.start()
        #expect(tracker.scroll.isTapped)
        tracker.stop()
        #expect(!tracker.scroll.isTapped)
        #expect(made == 1)
    }

    @Test("a refused tap is retried on the next change")
    func refusalRetries() {
        let gestures = ScrollGestures()
        var attempts = 0
        gestures.makeTap = { _ in
            attempts += 1
            return nil
        }
        gestures.onLog = { _ in }
        gestures.start()
        gestures.setHandler { _, _ in }
        gestures.configure(settings())
        gestures.setHandler { _, _ in }
        #expect(attempts == 2)
        #expect(!gestures.isTapped)
    }
}
