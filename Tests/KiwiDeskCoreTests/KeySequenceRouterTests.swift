import Carbon.HIToolbox
import Testing

@testable import KiwiDeskCore

/// What each key-down does to an open sequence (#1871 ▸ hint panel,
/// step keys).
@Suite("Key sequence router")
struct KeySequenceRouterTests {
    static let leader = KeyCombo.parse("ctrl+alt+space")!

    /// ⌃⌥Space → W → H fires 1, W → ⌃⌥W fires 2, T fires 3.
    static let sequence = KeySequence(
        leader: leader,
        stored: "ctrl+alt+space",
        steps: [
            key(
                "w",
                .opens([
                    key("h", .run(ref: 1)),
                    key("ctrl+alt+w", .run(ref: 2)),
                ])
            ),
            key("t", .run(ref: 3)),
        ]
    )

    static func key(_ text: String, _ action: KeySequence.Action)
        -> KeySequence.Key
    {
        KeySequence.Key(
            combo: KeyCombo.parse(text)!,
            stored: text,
            action: action
        )
    }

    private func router() -> KeySequenceRouter {
        var router = KeySequenceRouter()
        router.setSequences([Self.sequence])
        return router
    }

    private func press(
        _ router: inout KeySequenceRouter,
        _ text: String,
        isRepeat: Bool = false
    ) -> KeySequenceRouter.Outcome {
        let combo = KeyCombo.parse(text)!
        return router.press(
            keyCode: combo.keyCode,
            held: combo.modifiers,
            isRepeat: isRepeat
        )
    }

    @Test("A plain key with nothing open passes")
    func closedPasses() {
        var router = router()
        #expect(press(&router, "w") == .pass)
        #expect(!router.isOpen)
    }

    @Test("Leader, branch, end key fires and closes")
    func firesThroughABranch() {
        var router = router()
        #expect(press(&router, "ctrl+alt+space") == .stepped)
        #expect(press(&router, "w") == .stepped)
        #expect(
            router.progress
                == KeySequenceProgress(leader: "ctrl+alt+space", path: ["w"])
        )
        #expect(press(&router, "h") == .fired(ref: 1))
        #expect(!router.isOpen)
    }

    @Test("A step key matches its recorded chord strictly")
    func strictMatch() {
        var router = router()
        _ = press(&router, "ctrl+alt+space")
        _ = press(&router, "w")
        // The leader's modifiers still held are part of the key.
        #expect(press(&router, "ctrl+alt+h") == .unbound)
        #expect(router.isOpen)
        #expect(press(&router, "ctrl+alt+w") == .fired(ref: 2))
    }

    @Test("An unbound key stays on its step")
    func unboundStays() {
        var router = router()
        _ = press(&router, "ctrl+alt+space")
        #expect(press(&router, "q") == .unbound)
        #expect(router.progress?.path == [])
        #expect(press(&router, "t") == .fired(ref: 3))
    }

    @Test("esc closes; the leader again closes")
    func escAndLeaderClose() {
        var router = router()
        _ = press(&router, "ctrl+alt+space")
        _ = press(&router, "w")
        #expect(press(&router, "escape") == .closed)
        #expect(!router.isOpen)
        _ = press(&router, "ctrl+alt+space")
        #expect(press(&router, "ctrl+alt+space") == .closed)
        #expect(!router.isOpen)
    }

    @Test("⌫ goes back one step, and closes at the first")
    func deleteGoesBack() {
        var router = router()
        _ = press(&router, "ctrl+alt+space")
        _ = press(&router, "w")
        #expect(press(&router, "delete") == .back)
        #expect(router.progress?.path == [])
        #expect(press(&router, "delete") == .closed)
        #expect(!router.isOpen)
    }

    @Test("esc and ⌫ close or go back only when pressed plain")
    func plainOnly() {
        var router = router()
        _ = press(&router, "ctrl+alt+space")
        _ = press(&router, "w")
        #expect(press(&router, "ctrl+escape") == .unbound)
        #expect(press(&router, "cmd+delete") == .unbound)
        #expect(router.progress?.path == ["w"])
    }

    @Test("A keypad digit stands for its number-row step key")
    func keypadTwin() {
        var router = KeySequenceRouter()
        router.setSequences([
            KeySequence(
                leader: Self.leader,
                stored: "ctrl+alt+space",
                steps: [Self.key("2", .run(ref: 4))]
            )
        ])
        _ = press(&router, "ctrl+alt+space")
        #expect(
            router.press(
                keyCode: UInt32(kVK_ANSI_Keypad2),
                held: [],
                isRepeat: false
            ) == .fired(ref: 4)
        )
    }

    @Test("A tap leader opens, and the same tap again closes")
    func tapLeaderToggles() {
        var router = router()
        #expect(router.openLeader(0) == .stepped)
        #expect(router.isOpen)
        #expect(router.openLeader(0) == .closed)
        #expect(!router.isOpen)
        #expect(router.openLeader(9) == .pass)
    }

    @Test("A repeat neither opens nor moves a step")
    func repeatsAreSwallowed() {
        var router = router()
        #expect(press(&router, "ctrl+alt+space", isRepeat: true) == .pass)
        _ = press(&router, "ctrl+alt+space")
        // The leader's own auto-repeat must not read as a second press.
        #expect(press(&router, "ctrl+alt+space", isRepeat: true) == .repeated)
        #expect(router.isOpen)
    }

    @Test("New sequences close an open one")
    func replaceCloses() {
        var router = router()
        _ = press(&router, "ctrl+alt+space")
        router.setSequences([Self.sequence])
        #expect(!router.isOpen)
    }

    @Test("A sided step key answers only its side")
    func sidedStepKey() {
        var router = KeySequenceRouter()
        router.setSequences([
            KeySequence(
                leader: Self.leader,
                stored: "ctrl+alt+space",
                steps: [Self.key("lcmd+k", .run(ref: 9))]
            )
        ])
        _ = press(&router, "ctrl+alt+space")
        #expect(press(&router, "rcmd+k") == .unbound)
        #expect(press(&router, "lcmd+k") == .fired(ref: 9))
    }
}
