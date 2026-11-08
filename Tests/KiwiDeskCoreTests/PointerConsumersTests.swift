import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pointer tap's main-actor front (#2447, #2764 ruling): no
/// live consumer, no tap; the tap is built over the union of the
/// live consumers' masks; a refused tap is asked again only at a
/// start or a switch; and a grab in flight reads as a held button.
@Suite("PointerConsumers")
@MainActor
struct PointerConsumersTests {
    final class FakeTap: PointerTapHandle {
        var snapshots: [PointerTapSnapshot] = []
        var stopped = false
        func setSnapshot(_ snapshot: PointerTapSnapshot) {
            snapshots.append(snapshot)
        }
        func stop() { stopped = true }
    }

    @MainActor
    final class Rig {
        let front = PointerConsumers()
        var masks: [CGEventMask] = []
        var taps: [FakeTap] = []
        var refuse = false
        var heard: [ModifierGrabEvent] = []

        init(wired: Bool = true) {
            front.onLog = { _ in }
            front.makeTap = { [unowned self] mask, _ in
                masks.append(mask)
                guard !refuse else { return nil }
                let tap = FakeTap()
                taps.append(tap)
                return tap
            }
            if wired {
                front.setGrabHandler { [unowned self] in heard.append($0) }
            }
        }
    }

    private func event(
        _ phase: ModifierGrabEvent.Phase,
        x: CGFloat = 0
    ) -> ModifierGrabEvent {
        ModifierGrabEvent(
            phase: phase,
            action: .move,
            start: .drag,
            location: CGPoint(x: x, y: 0),
            time: 0
        )
    }

    @Test("no tap before the start, or with no wired consumer")
    func noConsumerNoTap() {
        let unwired = Rig(wired: false)
        unwired.front.start()
        #expect(unwired.masks.isEmpty)
        let rig = Rig()
        #expect(rig.masks.isEmpty)
        rig.front.start()
        #expect(rig.masks == [PointerConsumers.grabMask])
        #expect(rig.front.isTapped)
    }

    @Test("both actions off removes the tap; one back rebuilds it")
    func offRemovesTheTap() {
        let rig = Rig()
        rig.front.start()
        var off = ModifierDragSettings.defaults
        off.move.chord = []
        off.resize.chord = []
        rig.front.configure(grab: off)
        #expect(!rig.front.isTapped)
        #expect(rig.taps.first?.stopped == true)
        rig.front.configure(grab: .defaults)
        #expect(rig.taps.count == 2)
        #expect(rig.taps.last?.snapshots.last?.grab == .defaults)
    }

    @Test("the tap reads the sanitised settings")
    func snapshotIsSanitised() {
        let rig = Rig()
        rig.front.start()
        var settings = ModifierDragSettings.defaults
        settings.resize.chord = settings.move.chord
        rig.front.configure(grab: settings)
        #expect(rig.taps.last?.snapshots.last?.grab?.resize.isOff == true)
    }

    @Test("a refused tap is asked again once its switch moves")
    func refusalRetriesOnSwitch() {
        let rig = Rig()
        rig.refuse = true
        rig.front.start()
        rig.refuse = false
        var off = ModifierDragSettings.defaults
        off.move.chord = []
        off.resize.chord = []
        rig.front.configure(grab: off)
        rig.front.configure(grab: .defaults)
        #expect(rig.masks.count == 2)
        #expect(rig.front.isTapped)
    }

    @Test("a delivery an old tap queued is dropped after a rebuild")
    func staleTapIsDropped() {
        var delivers: [PointerTap.Deliver] = []
        let rig = Rig()
        rig.front.makeTap = { _, deliver in
            delivers.append(deliver)
            return FakeTap()
        }
        rig.front.start()
        rig.front.stop()
        rig.front.start()
        #expect(delivers.count == 2)
        // The first tap's began reaches the front after the second
        // tap is up: no router of the new tap would end it.
        rig.front.receive(
            .init(grab: [event(.began)], reenabled: false),
            fromTap: 1
        )
        #expect(rig.front.grabInFlight == nil)
        rig.front.receive(
            .init(grab: [event(.began)], reenabled: false),
            fromTap: 2
        )
        #expect(rig.front.grabInFlight != nil)
    }

    @Test("a refused tap is asked again only at the next start")
    func refusalWaits() {
        let rig = Rig()
        rig.refuse = true
        rig.front.start()
        rig.front.configure(grab: .defaults)
        rig.front.configure(grab: .defaults)
        #expect(rig.masks.count == 1)
        rig.refuse = false
        rig.front.stop()
        rig.front.start()
        #expect(rig.masks.count == 2)
        #expect(rig.front.isTapped)
    }

    @Test("a grab in flight is held; a batch's moves coalesce")
    func grabInFlight() {
        let rig = Rig()
        rig.front.start()
        rig.front.receive(
            .init(
                grab: [
                    event(.began), event(.moved, x: 1),
                    event(.moved, x: 2),
                ],
                reenabled: false
            )
        )
        #expect(rig.front.grabInFlight?.action == .move)
        #expect(rig.heard.map(\.phase) == [.began, .moved])
        #expect(rig.heard.last?.location?.x == 2)
        rig.front.receive(.init(grab: [event(.ended)], reenabled: false))
        #expect(rig.front.grabInFlight == nil)
    }

    @Test("a stop or an action turned off ends the grab in flight")
    func forcedEnd() {
        let rig = Rig()
        rig.front.start()
        rig.front.receive(.init(grab: [event(.began)], reenabled: false))
        var off = ModifierDragSettings.defaults
        off.move.chord = []
        rig.front.configure(grab: off)
        #expect(rig.front.grabInFlight == nil)
        #expect(rig.heard.last?.phase == .ended)
        #expect(rig.heard.last?.location == nil)
        rig.front.configure(grab: .defaults)
        rig.front.receive(.init(grab: [event(.began)], reenabled: false))
        rig.front.stop()
        #expect(rig.heard.map(\.phase).suffix(2) == [.began, .ended])
        // Queued after a stop: dropped with the tap.
        rig.front.receive(.init(grab: [event(.began)], reenabled: false))
        #expect(rig.front.grabInFlight == nil)
    }

    @Test("a grab in flight reads as a held left button")
    func trackerReadsTheGrab() {
        let tracker = MouseTracker()
        tracker.pressedButtons = { 0 }
        tracker.pointer.makeTap = { _, _ in FakeTap() }
        tracker.pointer.onLog = { _ in }
        tracker.pointer.setGrabHandler { _ in }
        #expect(!tracker.leftButtonHeld && !tracker.anyButtonHeld)
        tracker.pointer.start()
        tracker.pointer.receive(.init(grab: [event(.began)], reenabled: false))
        #expect(tracker.leftButtonHeld && tracker.anyButtonHeld)
        tracker.pointer.stop()
        #expect(!tracker.leftButtonHeld)
    }
}
