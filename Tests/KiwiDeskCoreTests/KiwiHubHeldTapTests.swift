import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// While KiwiHub is key a modifier tap fires nothing and a tap
/// leader opens no sequence (#1229): KiwiHub's own keys ride every
/// modifier. The hold is decided on the tap thread, so the leader
/// door is covered, and derived in Core from the own key window.
@Suite("KiwiHub holds modifier taps (#1229)", .serialized)
struct KiwiHubHeldTapTests {
    /// Fired ids, appended from the tap's lapse queue too.
    private final class Fired: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [UInt32] = []
        var ids: [UInt32] { lock.withLock { stored } }
        func append(_ id: UInt32) { lock.withLock { stored.append(id) } }
    }

    /// The tap's clock and the lapses it scheduled, stepped by hand
    /// (#3593), so no verdict reads how fast the runner is.
    private final class TapClock: @unchecked Sendable {
        private let lock = NSLock()
        private var time: TimeInterval = 100
        private var owed: [(TimeInterval, @Sendable () -> Void)] = []

        var now: TimeInterval { lock.withLock { time } }

        func schedule(
            _ delay: TimeInterval,
            _ work: @escaping @Sendable () -> Void
        ) {
            lock.withLock { owed.append((time + delay, work)) }
        }

        /// Moves the clock on and runs every lapse due by then.
        func advance(by seconds: TimeInterval) {
            let due = lock.withLock {
                time += seconds
                let due = owed.filter { $0.0 <= time }
                owed.removeAll { $0.0 <= time }
                return due.sorted { $0.0 < $1.0 }
            }
            for (_, work) in due { work() }
        }
    }

    private func unstarted(
        _ consumers: Set<KeyboardTapConsumer>,
        _ clock: TapClock,
        fire: @escaping KeyboardTap.Fire
    ) -> KeyboardTap {
        KeyboardTap.unstarted(
            consumers: consumers,
            fire: fire,
            clock: { clock.now },
            scheduleLapse: { clock.schedule($0, $1) }
        )
    }

    /// Just past a single tap's lapse.
    private static let pastTheGap = ModifierTapDetector.gapLimit + 0.01

    private func flags(_ raw: UInt64) throws -> CGEvent {
        let event = try #require(CGEvent(source: nil))
        event.type = .flagsChanged
        event.flags = CGEventFlags(rawValue: raw)
        return event
    }

    /// One press and release of a ⌘ key, by its device bit.
    private func tap(_ tap: KeyboardTap, device: UInt64) throws {
        let down = CGEventFlags.maskCommand.rawValue | device
        _ = tap.handledForTesting(.flagsChanged, try flags(down))
        _ = tap.handledForTesting(.flagsChanged, try flags(0))
    }

    private func doubleTapRig() throws -> (KeyboardTap, Fired) {
        let fired = Fired()
        let tap = unstarted([.modifierTaps], TapClock()) {
            fired.append($0)
        }
        let combo = try #require(KeyCombo.parse("cmd+cmd"))
        tap.setRows(
            KeyboardTapRows(taps: [ModifierTapRow(combo: combo, id: 1)])
        )
        return (tap, fired)
    }

    @Test("a held ⌘⌘ fires nothing; released, it fires")
    func heldDoubleTap() throws {
        let (tap, fired) = try doubleTapRig()
        tap.holdTaps(.all)
        try self.tap(tap, device: 0x08)
        try self.tap(tap, device: 0x08)
        #expect(fired.ids.isEmpty)
        tap.holdTaps(.none)
        try self.tap(tap, device: 0x08)
        try self.tap(tap, device: 0x08)
        #expect(fired.ids == [1])
    }

    @Test("a held tap leader opens no sequence")
    func heldLeader() throws {
        let fired = Fired()
        let tap = unstarted([.modifierTaps, .sequences], TapClock()) {
            fired.append($0)
        }
        let leader = try #require(KeyCombo.parse("rcmd"))
        tap.setRows(
            KeyboardTapRows(
                taps: [
                    ModifierTapRow(combo: leader, id: KeyboardTap.leaderID(0))
                ],
                sequences: [
                    KeySequence(
                        leader: leader,
                        stored: "rcmd",
                        steps: [
                            KeySequence.Key(
                                combo: try #require(KeyCombo.parse("t")),
                                stored: "t",
                                action: .run(ref: 7)
                            )
                        ]
                    )
                ]
            )
        )
        tap.holdTaps(.all)
        try self.tap(tap, device: 0x10)
        #expect(fired.ids.isEmpty)
        #expect(tap.drainSequenceDecisions().isEmpty)
        tap.holdTaps(.none)
        try self.tap(tap, device: 0x10)
        #expect(fired.ids == [KeyboardTap.sequenceFireID])
    }

    /// A right ⌘ single that waits on its double: it fires only at
    /// the gap's lapse, which the rig's clock steps to.
    private func lapseRig() throws -> (KeyboardTap, Fired, TapClock) {
        let fired = Fired()
        let clock = TapClock()
        let tap = unstarted([.modifierTaps], clock) { fired.append($0) }
        let single = try #require(KeyCombo.parse("rcmd"))
        let double = try #require(KeyCombo.parse("rcmd+rcmd"))
        tap.setRows(
            KeyboardTapRows(taps: [
                ModifierTapRow(combo: single, id: 1),
                ModifierTapRow(combo: double, id: 2),
            ])
        )
        return (tap, fired, clock)
    }

    @Test("a single held at its tap or at its lapse fires nothing")
    func heldLapse() throws {
        let (control, controlFired, controlClock) = try lapseRig()
        try tap(control, device: 0x10)
        #expect(controlFired.ids.isEmpty, "a single waits on its double")
        controlClock.advance(by: Self.pastTheGap)
        #expect(controlFired.ids == [1])

        let (atTap, atTapFired, atTapClock) = try lapseRig()
        atTap.holdTaps(.all)
        try tap(atTap, device: 0x10)
        atTap.holdTaps(.none)
        atTapClock.advance(by: Self.pastTheGap)
        #expect(atTapFired.ids.isEmpty)

        let (atLapse, atLapseFired, atLapseClock) = try lapseRig()
        try tap(atLapse, device: 0x10)
        atLapse.holdTaps(.all)
        atLapseClock.advance(by: Self.pastTheGap)
        #expect(atLapseFired.ids.isEmpty)
    }

    /// The hold follows the own key window: a floating panel holds
    /// it, any other window or none lets it go, and a tap built
    /// while held starts held.
    @Test("the hold is derived from the own key window")
    @MainActor
    func derivedFromKeyWindow() throws {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-hubtap-\(UUID().uuidString)")
        )
        var made: [FakeKeyboardTap] = []
        core.keys.makeKeyboardTap = { consumers, fire, _ in
            let tap = FakeKeyboardTap(consumers, fire)
            made.append(tap)
            return tap
        }
        var reading: OwnKeyWindowReading?
        core.eventLoop.ownKeyWindow = { reading }
        reading = OwnKeyWindowReading(
            number: 1,
            isDialog: false,
            floatsOverWindows: true
        )
        core.ownKeyWindowDidChange()
        core.keys.bind(try #require(KeyCombo.parse("cmd+cmd")), ref: 1)
        #expect(made.last?.held == .all)
        reading = OwnKeyWindowReading(number: 2, isDialog: false)
        core.ownKeyWindowDidChange()
        #expect(made.last?.held == ModifierTapHold.none)
        reading = OwnKeyWindowReading(
            number: 1,
            isDialog: false,
            floatsOverWindows: true
        )
        core.ownKeyWindowDidChange()
        #expect(made.last?.held == .all)
        reading = OwnKeyWindowReading(
            number: 3,
            isDialog: false,
            floatsOverWindows: true,
            isKiwiHub: true
        )
        core.ownKeyWindowDidChange()
        #expect(made.last?.held == .kiwiHub)
        reading = nil
        core.ownKeyWindowDidChange()
        #expect(made.last?.held == ModifierTapHold.none)
    }
}
