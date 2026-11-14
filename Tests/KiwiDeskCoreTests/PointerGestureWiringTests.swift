import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The gesture consumer's front and wiring (#1873): no bound pinch
/// or rotation, no gesture mask; a bound one widens the tap by
/// `gestureMask` alone; a delivered gesture reaches the touch
/// front's one match; and the core wires both doors at bootstrap.
@Suite("Pointer gesture wiring", .serialized)
@MainActor
struct PointerGestureWiringTests {
    private static let keys: ScrollChord = [.control, .option]

    final class FakeTap: PointerTapHandle {
        var snapshots: [PointerTapSnapshot] = []
        func setSnapshot(_ snapshot: PointerTapSnapshot) {
            snapshots.append(snapshot)
        }
        func stop() {}
    }

    @Test("no bound gesture, no mask; one bound widens by its own")
    func chordsArmTheMask() {
        let front = PointerConsumers()
        front.onLog = { _ in }
        var masks: [CGEventMask] = []
        var taps: [FakeTap] = []
        front.makeTap = { mask, _ in
            masks.append(mask)
            let tap = FakeTap()
            taps.append(tap)
            return tap
        }
        front.setGestureHandler { _ in }
        front.start()
        #expect(masks.isEmpty)
        front.configure(
            gestures: GestureEventSettings([.forceClick: [Self.keys]])
        )
        #expect(masks.isEmpty, "Force Click arms nothing")
        front.configure(gestures: GestureEventSettings([.rotate: [[]]]))
        #expect(masks.isEmpty, "an empty chord arms nothing")
        front.configure(gestures: GestureEventSettings([.rotate: [Self.keys]]))
        #expect(masks == [PointerConsumers.gestureMask])
        #expect(
            taps.last?.snapshots.last?.gestures?.chords
                == [.rotate: [Self.keys]]
        )
        front.configure(gestures: GestureEventSettings())
        #expect(!front.isTapped)
    }

    @Test("a delivered gesture reaches the handler")
    func deliveryReachesTheHandler() {
        let front = PointerConsumers()
        front.onLog = { _ in }
        front.makeTap = { _, _ in FakeTap() }
        var heard: [TrackpadGestureEvent] = []
        front.setGestureHandler { heard.append($0) }
        front.start()
        front.configure(gestures: GestureEventSettings([.spread: [Self.keys]]))
        let spread = TrackpadGestureEvent(
            kind: .gesture(.spread),
            fingers: 2,
            modifiers: Self.keys,
            time: 0
        )
        front.receive(
            PointerTapDelivery(
                grab: [],
                gestures: [spread],
                reenabled: false
            )
        )
        #expect(heard == [spread])
    }

    @Test("the core wires the chords in and the gestures out")
    func coreWiresBothDoors() throws {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-gestures-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try "".write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        let lua = try #require(core.keys.lua)
        var masks: [CGEventMask] = []
        core.mouse.pointer.makeTap = { mask, _ in
            masks.append(mask)
            return FakeTap()
        }
        core.mouse.pointer.start()
        core.mouse.trackpad.resolve(
            [
                GestureKey(.rotate, Self.keys): .run(
                    LuaAction(lua: "kiwi_rotated = true")
                )
            ],
            natural: true
        )
        core.mouse.trackpad.start()
        #expect(
            core.mouse.pointer.gestureSettings.chords
                == [.rotate: [Self.keys]]
        )
        #expect(
            masks.last.map { $0 & PointerConsumers.gestureMask }
                == PointerConsumers.gestureMask
        )
        // Out: a gesture the tap recognized runs the bound action.
        core.mouse.pointer.receive(
            PointerTapDelivery(
                grab: [],
                gestures: [
                    TrackpadGestureEvent(
                        kind: .gesture(.rotate),
                        fingers: 2,
                        modifiers: Self.keys,
                        time: 0
                    )
                ],
                reenabled: false
            )
        )
        #expect(lua.global("kiwi_rotated") == .bool(true))
        core.mouse.trackpad.stop()
        #expect(!core.mouse.pointer.gestureSettings.isOn)
        core.mouse.pointer.stop()
    }

    @Test("a Dock event carries the touch reader's finger count")
    func dockReadsTheFingerCount() throws {
        let event = try #require(CGEvent(source: nil))
        let dock = unsafeBitCast(UInt32(30), to: CGEventType.self)
        event.type = dock
        defer { TouchFingerCount.set(0) }
        TouchFingerCount.set(4)
        guard case .gesture(let sample)? = PointerTap.kind(of: dock, event)
        else {
            Issue.record("no gesture sample")
            return
        }
        #expect(sample.fingers == 4)
        let gesture = unsafeBitCast(UInt32(29), to: CGEventType.self)
        event.type = gesture
        guard case .gesture(let pinch)? = PointerTap.kind(of: gesture, event)
        else {
            Issue.record("no gesture sample")
            return
        }
        #expect(pinch.fingers == 0, "a type-29 sample reads no count")
    }

    @Test("a type-29 event reads as a gesture sample")
    func tapReadsTheFields() throws {
        let event = try #require(CGEvent(source: nil))
        func field(_ raw: UInt32) -> CGEventField {
            unsafeBitCast(raw, to: CGEventField.self)
        }
        let type = unsafeBitCast(UInt32(29), to: CGEventType.self)
        // A field is kept for the event's own type, so set it first.
        event.type = type
        event.setIntegerValueField(field(110), value: 8)
        event.setIntegerValueField(field(132), value: 2)
        event.setDoubleValueField(field(113), value: 0.25)
        #expect(
            PointerTap.kind(of: type, event)
                == .gesture(
                    GestureEventSample(subtype: 8, phase: 2, value: 0.25)
                )
        )
        let dock = unsafeBitCast(UInt32(30), to: CGEventType.self)
        event.type = dock
        event.setIntegerValueField(field(110), value: 23)
        event.setIntegerValueField(field(132), value: 2)
        event.setIntegerValueField(field(123), value: 3)
        event.setDoubleValueField(field(124), value: -0.5)
        #expect(
            PointerTap.kind(of: dock, event)
                == .gesture(
                    GestureEventSample(
                        subtype: 23,
                        phase: 2,
                        value: -0.5,
                        dock: true,
                        axis: 3
                    )
                )
        )
        let other = unsafeBitCast(UInt32(31), to: CGEventType.self)
        #expect(PointerTap.kind(of: other, event) == nil)
    }
}
