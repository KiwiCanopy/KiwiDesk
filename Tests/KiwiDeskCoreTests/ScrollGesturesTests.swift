import CoreGraphics
import Testing

@testable import KiwiDeskCore

private final class FakeTap: ScrollTapHandle {
    var chords: Set<ScrollChord> = []
    var deliver: ScrollGestureTap.Deliver?
    var stopped = false
    func setChords(_ chords: Set<ScrollChord>) { self.chords = chords }
    func stop() { stopped = true }
}

/// The tap's front (#1656, #1519): the machine tap exists only
/// while the core is started AND a chord is bound, and a routed
/// event reaches its chord's consumer alone.
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

    @Test("no tap until started and bound; none after the last unbind")
    func tapFollowsBindings() {
        let (gestures, made) = front()
        gestures.bind(Self.pan) { _ in }
        #expect(made().isEmpty)
        gestures.start()
        #expect(made().count == 1)
        #expect(made().first?.chords == [Self.pan])
        gestures.bind(Self.step) { _ in }
        #expect(made().count == 1)
        #expect(made().first?.chords == [Self.pan, Self.step])
        gestures.unbind(Self.pan)
        gestures.unbind(Self.step)
        #expect(made().first?.stopped == true)
        #expect(!gestures.isTapped)
    }

    @Test("stop tears the tap down")
    func stopTearsDown() {
        let (gestures, made) = front()
        gestures.start()
        #expect(made().isEmpty)
        gestures.bind(Self.pan) { _ in }
        gestures.stop()
        #expect(made().first?.stopped == true)
        #expect(!gestures.isTapped)
    }

    @Test("a plain scroll can never be bound")
    func emptyChordRefused() {
        let (gestures, made) = front()
        gestures.start()
        gestures.bind([]) { _ in }
        #expect(made().isEmpty)
    }

    @Test("an event reaches its own chord's consumer")
    func routesByChord() {
        let (gestures, _) = front()
        var heard: [ScrollChord] = []
        gestures.bind(Self.pan) { heard.append($0.chord) }
        gestures.bind(Self.step) { _ in heard.append([]) }
        gestures.receive([
            ScrollGestureEvent(
                chord: Self.pan,
                kind: .began,
                input: .wheel,
                delta: .zero,
                momentum: false,
                location: .zero
            )
        ])
        #expect(heard == [Self.pan])
    }

    @Test("what the tap routes reaches the consumer on the main queue")
    func tapDeliveryReachesConsumer() async {
        let (gestures, made) = front()
        var heard: [ScrollGestureEvent.Kind] = []
        gestures.bind(Self.pan) { heard.append($0.kind) }
        gestures.start()
        made().first?.deliver?([
            ScrollGestureEvent(
                chord: Self.pan,
                kind: .began,
                input: .trackpad,
                delta: .zero,
                momentum: false,
                location: .zero
            )
        ])
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
        tracker.scroll.bind(Self.pan) { _ in }
        #expect(made == 0)
        tracker.start()
        #expect(tracker.scroll.isTapped)
        tracker.stop()
        #expect(!tracker.scroll.isTapped)
        #expect(made == 1)
    }

    @Test("a refused tap is retried on the next bind")
    func refusalRetries() {
        let gestures = ScrollGestures()
        var attempts = 0
        gestures.makeTap = { _ in
            attempts += 1
            return nil
        }
        gestures.onLog = { _ in }
        gestures.start()
        gestures.bind(Self.pan) { _ in }
        gestures.bind(Self.step) { _ in }
        #expect(attempts == 2)
        #expect(!gestures.isTapped)
    }
}
