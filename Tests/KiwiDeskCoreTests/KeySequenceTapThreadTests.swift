import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The tap thread's half, driven with fabricated events on a tap
/// that never installs (#1871): what it swallows, and what it hands
/// the main actor.
@Suite("Key sequence tap thread")
struct KeySequenceTapThreadTests {
    private final class Fired: @unchecked Sendable {
        var ids: [UInt32] = []
    }

    private func tap(_ leader: String) throws -> (KeyboardTap, Fired) {
        let fired = Fired()
        let tap = KeyboardTap.unstarted(
            consumers: [.sequences],
            fire: { fired.ids.append($0) }
        )
        let combo = try #require(KeyCombo.parse(leader))
        tap.setRows(
            KeyboardTapRows(
                sequences: [
                    KeySequence(
                        leader: combo,
                        stored: leader,
                        steps: [
                            KeySequence.Key(
                                combo: try #require(KeyCombo.parse("t")),
                                stored: "t",
                                action: .run(ref: 7)
                            )
                        ]
                    )
                ],
                sequenceGeneration: 3
            )
        )
        return (tap, fired)
    }

    private func key(
        _ code: Int,
        _ flags: CGEventFlags = []
    ) throws -> CGEvent {
        let event = try #require(
            CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(code),
                keyDown: true
            )
        )
        event.flags = flags
        return event
    }

    @Test("a leader and the keys after it are swallowed; others pass")
    func swallowsWhileOpen() throws {
        let (tap, fired) = try tap("ctrl+alt+space")
        #expect(!tap.sequenceEvent(.keyDown, try key(17)))  // t, closed
        #expect(fired.ids.isEmpty)
        #expect(
            tap.sequenceEvent(
                .keyDown,
                try key(49, [.maskControl, .maskAlternate])
            )
        )
        #expect(tap.sequenceEvent(.keyDown, try key(12)))  // q, unbound
        #expect(tap.sequenceEvent(.keyDown, try key(17)))  // t fires
        #expect(
            fired.ids == Array(repeating: KeyboardTap.sequenceFireID, count: 3)
        )
        let drained = tap.drainSequenceDecisions()
        #expect(
            drained.map(\.outcome) == [.stepped, .unbound, .fired(ref: 7)]
        )
        #expect(drained.allSatisfy { $0.generation == 3 })
        #expect(tap.drainSequenceDecisions().isEmpty)
    }

    @Test("a click closes an open sequence and passes")
    func clickCloses() throws {
        let (tap, _) = try tap("ctrl+alt+space")
        let click = try #require(
            CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: .zero,
                mouseButton: .left
            )
        )
        #expect(!tap.sequenceEvent(.leftMouseDown, click))
        #expect(tap.drainSequenceDecisions().isEmpty)
        _ = tap.sequenceEvent(
            .keyDown,
            try key(49, [.maskControl, .maskAlternate])
        )
        #expect(!tap.sequenceEvent(.leftMouseDown, click))
        #expect(
            tap.drainSequenceDecisions().map(\.outcome) == [.stepped, .closed]
        )
        #expect(!tap.sequenceEvent(.keyDown, try key(17)))
    }

    @Test("a main-actor close is taken at the next event, with its epoch")
    func mainCloseIsTaken() throws {
        let (tap, _) = try tap("ctrl+alt+space")
        _ = tap.sequenceEvent(
            .keyDown,
            try key(49, [.maskControl, .maskAlternate])
        )
        tap.requestSequenceClose(generation: 5)
        #expect(!tap.sequenceEvent(.keyDown, try key(17)))
        _ = tap.sequenceEvent(
            .keyDown,
            try key(49, [.maskControl, .maskAlternate])
        )
        let drained = tap.drainSequenceDecisions()
        #expect(drained.map(\.outcome) == [.stepped, .stepped])
        #expect(drained.map(\.generation) == [3, 5])
    }

    @Test("new rows close the sequence and drop what waited")
    func newRowsDropTheQueue() throws {
        let (tap, _) = try tap("ctrl+alt+space")
        _ = tap.sequenceEvent(
            .keyDown,
            try key(49, [.maskControl, .maskAlternate])
        )
        tap.setRows(.empty)
        #expect(tap.drainSequenceDecisions().isEmpty)
        #expect(!tap.sequenceEvent(.keyDown, try key(17)))
    }

    @Test("the callback swallows what the consumer takes, and a gap closes")
    func callbackRoutes() throws {
        let (tap, _) = try tap("ctrl+alt+space")
        #expect(!tap.handledForTesting(.keyDown, try key(17)))
        let leader = try key(49, [.maskControl, .maskAlternate])
        #expect(tap.handledForTesting(.keyDown, leader))
        #expect(!tap.handledForTesting(.tapDisabledByTimeout, leader))
        #expect(
            tap.drainSequenceDecisions().map(\.outcome) == [.stepped, .closed]
        )
    }

    @Test("a gap in the tap closes an open sequence")
    func gapCloses() throws {
        let (tap, fired) = try tap("ctrl+alt+space")
        tap.closeSequenceAfterGap()
        #expect(fired.ids.isEmpty)
        _ = tap.sequenceEvent(
            .keyDown,
            try key(49, [.maskControl, .maskAlternate])
        )
        tap.closeSequenceAfterGap()
        #expect(fired.ids.count == 2)
        #expect(
            tap.drainSequenceDecisions().map(\.outcome) == [.stepped, .closed]
        )
    }

    @Test("a tap leader opens through the modifier-tap id")
    func tapLeaderOpens() throws {
        let (tap, fired) = try tap("cmd+cmd")
        tap.fireOrOpen(KeyboardTap.leaderID(0))
        #expect(fired.ids == [KeyboardTap.sequenceFireID])
        #expect(tap.drainSequenceDecisions().map(\.outcome) == [.stepped])
        tap.fireOrOpen(5)
        #expect(fired.ids.last == 5)
        tap.fireOrOpen(KeyboardTap.leaderID(0))
        #expect(tap.drainSequenceDecisions().map(\.outcome) == [.closed])
    }
}

/// A switch or a Desktop change closes an open sequence (#1871 ▸
/// hint panel): the core's door asks the tap and tells the panel,
/// and the two switch doors call it.
@MainActor
@Suite("Key sequence closers")
struct KeySequenceCloserTests {
    @Test("the core's close asks the tap and clears the panel")
    func coreCloses() throws {
        let core = makeTestCore()
        var made: [FakeKeyboardTap] = []
        core.keys.makeKeyboardTap = { consumers, fire, _ in
            let tap = FakeKeyboardTap(consumers, fire)
            made.append(tap)
            return tap
        }
        var seen: [KeySequenceProgress?] = []
        core.onKeySequence = { seen.append($0) }
        core.keys.defineSequence(
            KeySequence(
                leader: try #require(KeyCombo.parse("ctrl+alt+space")),
                stored: "ctrl+alt+space",
                steps: []
            ),
            in: "default"
        )
        let tap = try #require(made.last)
        let open = KeySequenceProgress(leader: "ctrl+alt+space", path: [])
        core.keys.sequenceDecided(
            KeySequenceDecision(
                outcome: .stepped,
                progress: open,
                generation: core.keys.sequenceGeneration
            )
        )
        core.closeKeySequence()
        #expect(tap.closeRequests == 1)
        #expect(seen == [open, nil])
    }
}
