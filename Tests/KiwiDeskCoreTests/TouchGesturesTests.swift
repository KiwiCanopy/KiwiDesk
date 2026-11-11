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
    private typealias Fired = (GestureInput, TrackpadGestureEvent)

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
        gestures.setHandler { key, _, event in
            box.fired.append((key.input, event))
        }
        return (gestures, box)
    }

    /// `entries` alone, the seeds left out, so only `entries`
    /// read touches.
    private func map(
        _ entries: [GestureKey: GestureAction]
    ) -> [GestureKey: GestureAction] {
        entries
    }

    @Test("no touch slot bound, no reader; one bound starts it")
    func readerFollowsTheBindings() {
        let (gestures, box) = front()
        gestures.resolve(map([:]), natural: true)
        gestures.start()
        #expect(box.readers.isEmpty, "a pinch slot reads no touches")
        #expect(!gestures.isReading)
        gestures.resolve(
            map([GestureKey(.tap4): .run(LuaAction(lua: "x()"))]),
            natural: true
        )
        #expect(box.readers.count == 1)
        gestures.resolve(map([:]), natural: true)
        #expect(box.readers.first?.stopped == true)
        #expect(!gestures.isReading)
    }

    @Test("the seeds start the reader on a default install")
    func seedsStartTheReader() {
        let (gestures, box) = front()
        gestures.resolve(
            GestureSeeds.resolved(base: GestureMap(), profile: nil),
            natural: true
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
            map([
                GestureKey(.swipe3, Self.hyper): .family(.focus)
            ]),
            natural: true
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
            map([
                GestureKey(.tap3): .run(LuaAction(lua: "a()")),
                GestureKey(.tap4): .run(LuaAction(lua: "b()")),
                GestureKey(.swipe3, Self.hyper): .family(.focus),
            ]),
            natural: true
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

    @Test("an input the touch router never fires starts no reader")
    func unfiredStartsNoReader() {
        let (gestures, box) = front()
        gestures.resolve(
            map([GestureKey(.tap2): .run(LuaAction(lua: "a()"))]),
            natural: true
        )
        gestures.start()
        #expect(box.readers.isEmpty)
    }

    @Test("Natural off flips a family's swipe, never a table's arm")
    func naturalOffFlipsFamiliesOnly() {
        let (gestures, box) = front()
        gestures.resolve(
            map([
                GestureKey(.swipe3, Self.hyper): .family(.focus),
                GestureKey(.swipe4, Self.hyper): .split([
                    .up: LuaAction(lua: "a()")
                ]),
            ]),
            natural: false
        )
        gestures.start()
        gestures.receive([
            event(.swipe(.up), 3, Self.hyper),
            event(.swipe(.up), 4, Self.hyper),
        ])
        #expect(box.fired.map(\.1.kind) == [.swipe(.down), .swipe(.up)])
    }

    @Test("the preferences are read afresh for each batch")
    func prefsReadPerBatch() {
        final class Prefs { var system = TrackpadSystemGestures.unread }
        let prefs = Prefs()
        let (gestures, box) = front()
        gestures.readSystemGestures = { prefs.system }
        gestures.resolve(
            map([GestureKey(.tap3): .run(LuaAction(lua: "a()"))]),
            natural: true
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
            map([GestureKey(.tap4): .run(LuaAction(lua: "b()"))]),
            natural: true
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
            map([GestureKey(.tap4): .run(LuaAction(lua: "b()"))]),
            natural: true
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
        var pushed: [[GestureInput: Set<ScrollChord>]] = []
        gestures.onGestureEventChords = { pushed.append($0) }
        gestures.resolve(
            map([
                GestureKey(.rotate, Self.hyper): .run(LuaAction(lua: "r()")),
                GestureKey(.rotate, [.option, .command]): .run(
                    LuaAction(lua: "s()")
                ),
            ]),
            natural: true
        )
        #expect(pushed.last == [:], "nothing before the start")
        gestures.start()
        #expect(pushed.last == [.rotate: [Self.hyper, [.option, .command]]])
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
        let tapOne = TrackpadSystemGestures.parse([
            "TrackpadThreeFingerTapGesture": 1
        ])
        #expect(tapOne.lookUpTap, "any value but 0 is macOS's")
        let drag = TrackpadSystemGestures.parse(["TrackpadThreeFingerDrag": 1])
        #expect(drag.swipes[3] == [.horizontal, .vertical])
        #expect(drag.swipes[4] == nil)
        let none = TrackpadSystemGestures.parse([:])
        #expect(!none.read)
        #expect(!none.owns(event(.tap, 3)))
        #expect(!none.owns(event(.swipe(.left), 4)))
    }
}
