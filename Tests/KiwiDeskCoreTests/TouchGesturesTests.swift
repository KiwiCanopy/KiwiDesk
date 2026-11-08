import Foundation
import Testing

@testable import KiwiDeskCore

private final class FakeReader: TouchReaderHandle {
    var deliver: TouchReader.Deliver?
    var stopped = false
    func stop() { stopped = true }
}

/// The reader's front (#1873 ruling ▸ Reader): no binding, no
/// reader; a gesture reaches the handler only on its slot's exact
/// modifiers and never where macOS answers it itself.
@MainActor
@Suite("Touch gestures front")
struct TouchGesturesTests {
    private static let hyper: ScrollChord = [.control, .option]
    private typealias Fired = (TrackpadGestureSlot, TrackpadGestureEvent)

    private final class Box {
        var readers: [FakeReader] = []
        var fired: [Fired] = []
    }

    private func front(
        system: TrackpadSystemGestures = .unread
    ) -> (TouchGestures, Box) {
        let gestures = TouchGestures()
        let box = Box()
        gestures.onLog = { _ in }
        gestures.readSystemGestures = { system }
        gestures.makeReader = { deliver in
            let reader = FakeReader()
            reader.deliver = deliver
            box.readers.append(reader)
            return reader
        }
        gestures.setHandler { slot, _, event in
            box.fired.append((slot, event))
        }
        return (gestures, box)
    }

    /// `entries`, with every other touch slot unbound, so only
    /// `entries` read touches.
    private func map(
        _ entries: [TrackpadGestureSlot: TrackpadGestureEntry]
    ) -> TrackpadGestureMap {
        var all = entries
        for slot in TrackpadGestureSlot.allCases
        where slot.source == .touches && all[slot] == nil {
            all[slot] = .unbound
        }
        return TrackpadGestureMap(all)
    }

    @Test("no touch slot bound, no reader; one bound starts it")
    func readerFollowsTheBindings() {
        let (gestures, box) = front()
        gestures.resolve(base: map([:]), profileOverride: nil)
        gestures.start()
        #expect(box.readers.isEmpty, "a pinch slot reads no touches")
        #expect(!gestures.isReading)
        gestures.resolve(
            base: map([.tap4: .bound(.init(action: "x()"))]),
            profileOverride: nil
        )
        #expect(box.readers.count == 1)
        gestures.resolve(
            base: map([:]),
            profileOverride: nil
        )
        #expect(box.readers.first?.stopped == true)
        #expect(!gestures.isReading)
    }

    @Test("the seeds start the reader on a default install")
    func seedsStartTheReader() {
        let (gestures, box) = front()
        gestures.resolve(
            base: TrackpadGestureMap(),
            profileOverride: nil
        )
        #expect(box.readers.isEmpty, "not before the start")
        gestures.start()
        #expect(box.readers.count == 1)
        gestures.stop()
        #expect(box.readers.first?.stopped == true)
    }

    private func event(
        _ kind: TrackpadGestureEvent.Kind,
        _ fingers: Int,
        _ modifiers: ScrollChord = []
    ) -> TrackpadGestureEvent {
        TrackpadGestureEvent(
            kind: kind,
            fingers: fingers,
            modifiers: modifiers,
            time: 0
        )
    }

    @Test("a gesture fires its slot on the exact modifiers only")
    func exactModifiers() {
        let (gestures, box) = front()
        gestures.resolve(
            base: map([
                .swipe3: .bound(.init(action: "focus", modifiers: Self.hyper))
            ]),
            profileOverride: nil
        )
        gestures.start()
        gestures.receive([
            event(.swipe(.left), 3, [.control]),
            event(.swipe(.left), 3, [.control, .option, .command]),
            event(.swipe(.left), 4, Self.hyper),
            event(.swipe(.left), 3, Self.hyper),
        ])
        #expect(box.fired.map(\.0) == [.swipe3])
        #expect(box.fired.first?.1.kind == .swipe(.left))
    }

    @Test("a gesture macOS answers itself does not fire")
    func systemOwnedStandsDown() {
        let system = TrackpadSystemGestures(
            swipes: [3: [.horizontal]],
            lookUpTap: true
        )
        let (gestures, box) = front(system: system)
        gestures.resolve(
            base: map([
                .tap3: .bound(.init(action: "a()")),
                .tap4: .bound(.init(action: "b()")),
                .swipe3: .bound(.init(action: "focus", modifiers: Self.hyper)),
            ]),
            profileOverride: nil
        )
        gestures.start()
        gestures.receive([
            event(.tap, 3),
            event(.swipe(.right), 3, Self.hyper),
            event(.swipe(.up), 3, Self.hyper),
            event(.tap, 4),
        ])
        #expect(box.fired.map(\.0) == [.swipe3, .tap4])
        #expect(box.fired.first?.1.kind == .swipe(.up))
    }

    @Test("the preferences are read afresh for each batch")
    func prefsReadPerBatch() {
        final class Prefs { var system = TrackpadSystemGestures.unread }
        let prefs = Prefs()
        let (gestures, box) = front()
        gestures.readSystemGestures = { prefs.system }
        gestures.resolve(
            base: map([.tap3: .bound(.init(action: "a()"))]),
            profileOverride: nil
        )
        gestures.start()
        gestures.receive([event(.tap, 3)])
        prefs.system = TrackpadSystemGestures(lookUpTap: true)
        gestures.receive([event(.tap, 3)])
        prefs.system = .unread
        gestures.receive([event(.tap, 3)])
        #expect(box.fired.count == 2)
    }

    @Test("a rearm builds the reader afresh, and none while stopped")
    func rearmRebuilds() {
        let (gestures, box) = front()
        gestures.resolve(
            base: map([.tap4: .bound(.init(action: "b()"))]),
            profileOverride: nil
        )
        gestures.rearm()
        #expect(box.readers.isEmpty, "stopped: nothing to rebuild")
        gestures.start()
        gestures.rearm()
        #expect(box.readers.count == 2)
        #expect(box.readers.first?.stopped == true)
        #expect(box.readers.last?.stopped == false)
    }

    @Test("nothing fires before the start or after the stop")
    func stoppedDropsEvents() {
        let (gestures, box) = front()
        gestures.resolve(
            base: map([.tap4: .bound(.init(action: "b()"))]),
            profileOverride: nil
        )
        gestures.receive([event(.tap, 4)])
        gestures.start()
        gestures.stop()
        gestures.receive([event(.tap, 4)])
        #expect(box.fired.isEmpty)
    }

    @Test("the gesture-event chords reach their door, empty when off")
    func gestureEventChordsReachTheDoor() {
        let (gestures, box) = front()
        var pushed: [[TrackpadGestureSlot: ScrollChord]] = []
        gestures.onGestureEventChords = { pushed.append($0) }
        gestures.resolve(
            base: TrackpadGestureMap([.spread: .unbound]),
            profileOverride: nil
        )
        #expect(pushed.last == [:], "nothing before the start")
        gestures.start()
        #expect(pushed.last == [.rotate: Self.hyper])
        gestures.receive([event(.gesture(.rotate), 0, Self.hyper)])
        gestures.receive([event(.gesture(.tap3), 0)])
        #expect(box.fired.map(\.0) == [.rotate])
        gestures.stop()
        #expect(pushed.last == [:])
    }

    @Test("the preference read decides which gestures macOS owns")
    func systemPrefsParse() {
        let parsed = TrackpadSystemGestures.parse([
            "TrackpadThreeFingerHorizSwipeGesture": 2,
            "TrackpadThreeFingerVertSwipeGesture": 1,
            "TrackpadFourFingerHorizSwipeGesture": 0,
            "TrackpadFourFingerVertSwipeGesture": 2,
            "TrackpadThreeFingerTapGesture": 2,
        ])
        #expect(parsed.read)
        #expect(parsed.swipes[3] == [.horizontal, .vertical])
        #expect(parsed.swipes[4] == [.vertical])
        #expect(parsed.lookUpTap)
        let drag = TrackpadSystemGestures.parse(["TrackpadThreeFingerDrag": 1])
        #expect(drag.swipes[3] == [.horizontal, .vertical])
        #expect(drag.swipes[4] == nil)
        let none = TrackpadSystemGestures.parse([:])
        #expect(!none.read)
        #expect(!none.owns(event(.tap, 3)))
        #expect(!none.owns(event(.swipe(.left), 4)))
    }
}
