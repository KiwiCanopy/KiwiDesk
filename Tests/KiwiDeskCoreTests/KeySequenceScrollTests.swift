import Carbon.HIToolbox
import Testing

@testable import KiwiDeskCore

/// KiwiHub's navigation keys scroll an open sequence's panel
/// (#3175 ▸ Ruling): the plain arrows and page keys, then the user's
/// second chords; a recorded step key outranks them, and a held key
/// repeat-scrolls.
@Suite("Key sequence scroll keys")
struct KeySequenceScrollTests {
    typealias Router = KeySequenceRouterTests

    /// ⌃⌥Space → ↓ fires 7: an arrow recorded as a step key.
    static let arrowStep = KeySequence(
        leader: Router.leader,
        stored: "ctrl+alt+space",
        steps: [Router.key("down", .run(ref: 7))]
    )

    private func router(
        _ sequence: KeySequence = Router.sequence,
        keys: KiwiHubKeys = KiwiHubKeys()
    ) -> KeySequenceRouter {
        var router = KeySequenceRouter()
        router.setSequences([sequence])
        router.scrollKeys = keys
        _ = press(&router, "ctrl+alt+space")
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

    private static var emacs: KiwiHubKeys {
        var keys = KiwiHubKeys()
        keys.down = "ctrl+n"
        keys.pageDown = "ctrl+d"
        return keys
    }

    @Test("The arrows and page keys scroll the open panel")
    func builtInKeysScroll() {
        var router = router()
        #expect(press(&router, "down") == .scroll(.step(1)))
        #expect(press(&router, "up") == .scroll(.step(-1)))
        #expect(press(&router, "pagedown") == .scroll(.page(1)))
        #expect(press(&router, "pageup") == .scroll(.page(-1)))
        #expect(router.isOpen)
        #expect(KeySequenceRouter.Outcome.scroll(.step(1)).swallows)
    }

    @Test("A recorded step key outranks an arrow")
    func stepKeyBeatsArrow() {
        var router = router(Self.arrowStep)
        #expect(press(&router, "down") == .fired(ref: 7))
    }

    @Test("A second chord scrolls under an arrow step key")
    func secondChordScrolls() {
        var router = router(Self.arrowStep, keys: Self.emacs)
        #expect(press(&router, "ctrl+n") == .scroll(.step(1)))
        #expect(press(&router, "ctrl+d") == .scroll(.page(1)))
        // No ⇧ strip: ⌃⇧N is no second chord.
        #expect(press(&router, "ctrl+shift+n") == .unbound)
    }

    @Test("A held arrow repeat-scrolls; a held step key stays still")
    func repeatScrolls() {
        var router = router()
        #expect(press(&router, "down", isRepeat: true) == .scroll(.step(1)))
        #expect(press(&router, "w", isRepeat: true) == .repeated)
        #expect(press(&router, "x", isRepeat: true) == .repeated)
        #expect(router.progress?.path == [])
    }

    @Test("Closed, an arrow passes")
    func closedPasses() {
        var router = KeySequenceRouter()
        router.setSequences([Router.sequence])
        #expect(press(&router, "down") == .pass)
    }

    @Test("A main-actor scroll decision reaches the panel")
    @MainActor
    func managerHandsOnScroll() {
        let manager = KeybindingManager(registrar: NoopHotkeyRegistrar())
        var heard: [KeySequenceScroll] = []
        manager.onSequenceScroll = { heard.append($0) }
        manager.sequenceDecided(.init(outcome: .scroll(.step(1))))
        manager.sequenceDecided(.init(outcome: .scroll(.page(-1))))
        #expect(heard == [.step(1), .page(-1)])
    }
}
