import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// How key sequences reach the one keyboard tap (#1871): the
/// `.sequences` consumer is declared first and swallows, a leader
/// never reaches Carbon, a tap leader rides `.modifierTaps`, and the
/// main actor acts on what the tap decided.
@Suite("Key sequence tap", .serialized)
@MainActor
struct KeySequenceTapTests {
    private func rig() -> (KeybindingManager, () -> [FakeKeyboardTap]) {
        let manager = KeybindingManager(registrar: NoopHotkeyRegistrar())
        manager.onLog = { _ in }
        manager.beep = {}
        var made: [FakeKeyboardTap] = []
        manager.makeKeyboardTap = { consumers, fire, _ in
            let tap = FakeKeyboardTap(consumers, fire)
            made.append(tap)
            return tap
        }
        return (manager, { made })
    }

    private func sequence(_ leader: String) throws -> KeySequence {
        KeySequence(
            leader: try #require(KeyCombo.parse(leader)),
            stored: leader,
            steps: [
                KeySequence.Key(
                    combo: try #require(KeyCombo.parse("t")),
                    stored: "t",
                    action: .run(ref: 7)
                )
            ]
        )
    }

    @Test("the sequences consumer is first, swallows and hears clicks")
    func consumerShape() {
        #expect(KeyboardTapConsumer.allCases.first == .sequences)
        #expect(KeyboardTapConsumer.sequences.swallows)
        let mask = KeyboardTapConsumer.sequencesMask
        #expect(mask & (1 << CGEventType.keyDown.rawValue) != 0)
        for click in [
            CGEventType.leftMouseDown, .rightMouseDown, .otherMouseDown,
        ] {
            #expect(mask & (1 << click.rawValue) != 0)
        }
        #expect(
            KeyboardTapRows(sequences: [
                KeySequence(
                    leader: KeyCombo(keyCode: 49, modifiers: [.control]),
                    stored: "ctrl+space",
                    steps: []
                )
            ]).consumers == [.sequences]
        )
    }

    @Test("a defined sequence reaches the tap, its leader not Carbon")
    func reachesTheTap() throws {
        let (manager, taps) = rig()
        manager.defineSequence(try sequence("ctrl+alt+space"), in: "default")
        let tap = try #require(taps().last)
        #expect(tap.consumers == [.sequences])
        #expect(tap.sequences.map(\.stored) == ["ctrl+alt+space"])
        #expect(manager.activeBindings.isEmpty)
    }

    @Test("a tap leader rides the modifier-tap router under its id")
    func tapLeader() throws {
        let (manager, taps) = rig()
        manager.defineSequence(try sequence("cmd+cmd"), in: "default")
        let tap = try #require(taps().last)
        #expect(tap.consumers == [.sequences, .modifierTaps])
        #expect(tap.tapRows.map(\.id) == [KeyboardTap.leaderID(0)])
    }

    @Test("a suspended manager hands the tap no sequence")
    func suspendedHandsNone() throws {
        let (manager, taps) = rig()
        manager.defineSequence(try sequence("ctrl+alt+space"), in: "default")
        manager.suspend()
        #expect(taps().last?.sequences.isEmpty == true)
        // A sequence defined while suspended reaches no tap either.
        manager.defineSequence(try sequence("ctrl+alt+k"), in: "default")
        #expect(taps().last?.sequences.isEmpty == true)
    }

    @Test("a refused tap names the leader a failure")
    func refusedTapFails() throws {
        let manager = KeybindingManager(registrar: NoopHotkeyRegistrar())
        manager.onLog = { _ in }
        manager.makeKeyboardTap = { _, _, _ in nil }
        let held = try sequence("ctrl+alt+space")
        manager.defineSequence(held, in: "default")
        #expect(manager.activationFailures.contains(held.leader))
    }

    @Test("decisions drive the panel; an unbound key beeps")
    func decisionsDriveThePanel() throws {
        let (manager, taps) = rig()
        var beeps = 0
        manager.beep = { beeps += 1 }
        var seen: [KeySequenceProgress?] = []
        manager.onSequenceProgress = { seen.append($0) }
        manager.defineSequence(try sequence("ctrl+alt+space"), in: "default")
        let tap = try #require(taps().last)
        let open = KeySequenceProgress(leader: "ctrl+alt+space", path: [])
        tap.decisions = [
            KeySequenceDecision(
                outcome: .stepped,
                progress: open,
                generation: manager.sequenceGeneration
            ),
            KeySequenceDecision(
                outcome: .unbound,
                progress: open,
                generation: manager.sequenceGeneration
            ),
            KeySequenceDecision(
                outcome: .closed,
                progress: nil,
                generation: manager.sequenceGeneration
            ),
        ]
        manager.tapFire(KeyboardTap.sequenceFireID)
        #expect(seen == [open, nil])
        #expect(beeps == 1)
    }

    @Test("a decision made over older rows is dropped")
    func staleDecisionIsDropped() throws {
        let (manager, taps) = rig()
        var seen: [KeySequenceProgress?] = []
        manager.onSequenceProgress = { seen.append($0) }
        manager.defineSequence(try sequence("ctrl+alt+space"), in: "default")
        let stale = manager.sequenceGeneration
        manager.defineSequence(try sequence("ctrl+alt+k"), in: "default")
        let tap = try #require(taps().last)
        tap.decisions = [
            KeySequenceDecision(
                outcome: .stepped,
                progress: KeySequenceProgress(leader: "x", path: []),
                generation: stale
            )
        ]
        manager.tapFire(KeyboardTap.sequenceFireID)
        #expect(seen.isEmpty)
        #expect(manager.sequenceGeneration != stale)
    }

    @Test("a main-actor close asks the tap and tells the panel")
    func mainCloses() throws {
        let (manager, taps) = rig()
        var seen: [KeySequenceProgress?] = []
        manager.onSequenceProgress = { seen.append($0) }
        manager.closeSequence()  // no sequence defined, nothing asked
        manager.defineSequence(try sequence("ctrl+alt+space"), in: "default")
        let tap = try #require(taps().last)
        let open = KeySequenceProgress(leader: "ctrl+alt+space", path: [])
        let gen = manager.sequenceGeneration
        tap.decisions = [
            KeySequenceDecision(
                outcome: .stepped,
                progress: open,
                generation: gen
            )
        ]
        manager.tapFire(KeyboardTap.sequenceFireID)
        manager.closeSequence()
        #expect(tap.closeRequests == 1)
        #expect(seen == [open, nil])
    }

    @Test("a leader in flight when the main actor closes stays closed")
    func closeBeatsALeaderInFlight() throws {
        let (manager, taps) = rig()
        var seen: [KeySequenceProgress?] = []
        manager.onSequenceProgress = { seen.append($0) }
        manager.defineSequence(try sequence("ctrl+alt+space"), in: "default")
        let tap = try #require(taps().last)
        let before = manager.sequenceGeneration
        // The panel is shut, yet the tap is asked: a leader's step
        // may be on its way.
        manager.closeSequence()
        #expect(tap.closeRequests == 1)
        #expect(manager.sequenceGeneration != before)
        let open = KeySequenceProgress(leader: "ctrl+alt+space", path: [])
        tap.decisions = [
            KeySequenceDecision(
                outcome: .stepped,
                progress: open,
                generation: before
            ),
            KeySequenceDecision(
                outcome: .stepped,
                progress: open,
                generation: manager.sequenceGeneration
            ),
        ]
        manager.tapFire(KeyboardTap.sequenceFireID)
        #expect(seen == [open])
    }

    @Test("new rows close the panel with the tap's sequence")
    func reactivateCloses() throws {
        let (manager, taps) = rig()
        var seen: [KeySequenceProgress?] = []
        manager.onSequenceProgress = { seen.append($0) }
        manager.defineSequence(try sequence("ctrl+alt+space"), in: "default")
        let tap = try #require(taps().last)
        let open = KeySequenceProgress(leader: "ctrl+alt+space", path: [])
        tap.decisions = [
            KeySequenceDecision(
                outcome: .stepped,
                progress: open,
                generation: manager.sequenceGeneration
            )
        ]
        manager.tapFire(KeyboardTap.sequenceFireID)
        manager.reset()
        #expect(seen == [open, nil])
    }

    @Test("the tap state records only what the main actor must hear")
    func tapStateRecords() throws {
        var state = SequenceTapState()
        state.router.setSequences([try sequence("ctrl+alt+space")])
        let passed = state.record(.pass)
        let repeated = state.record(.repeated)
        let opened = state.router.openLeader(0)
        let heard = state.record(opened)
        #expect(!passed && !repeated && heard)
        #expect(state.waiting.last?.progress?.path == [])
        state.closeRequested = 9
        state.takeClose()
        #expect(!state.router.isOpen)
        #expect(state.closeRequested == nil)
        #expect(state.generation == 9)
    }
}
