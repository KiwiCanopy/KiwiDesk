import Carbon.HIToolbox
import Testing

@testable import KiwiDeskCore

/// An open key sequence lets macOS's own shortcuts through in three
/// tiers (#3173 ▸ Ruling): a recorded step key first, then a shortcut
/// that takes no keyboard (the panel stays), one that takes the
/// keyboard (the sequence closes), and an app's menu chord, which
/// stays swallowed.
@Suite("Key sequence pass-through")
struct KeySequencePassTests {
    typealias Router = KeySequenceRouterTests

    /// ⌃⌥Space → ⌘⇧4 fires 9: a step key on a macOS chord.
    static let stepOnScreenshot = KeySequence(
        leader: Router.leader,
        stored: "ctrl+alt+space",
        steps: [
            Router.key("t", .run(ref: 3)),
            Router.key("cmd+shift+4", .run(ref: 9)),
        ]
    )

    private func router(
        _ sequence: KeySequence = Router.sequence,
        read: (Int) -> SymbolicHotkeyEntry? = { _ in nil }
    ) -> KeySequenceRouter {
        var router = KeySequenceRouter()
        router.setSequences([sequence], passing: .live(reading: read))
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

    @Test("A screenshot passes and the panel stays open")
    func screenshotStaysOpen() {
        var router = router()
        _ = press(&router, "ctrl+alt+space")
        let outcome = press(&router, "cmd+shift+4")
        #expect(outcome == .passed(closing: false))
        #expect(!outcome.swallows)
        #expect(router.isOpen)
    }

    @Test("Spotlight and Desktop switching pass and close")
    func keyboardTakersClose() {
        // ⌃2 ships off: it passes once macOS has it on.
        let desktop2 = SystemShortcut.switchToDesktop2.symbolicHotkey!.id
        for chord in ["cmd+space", "ctrl+right", "ctrl+2", "cmd+tab"] {
            var router = router {
                $0 == desktop2 ? SymbolicHotkeyEntry(enabled: true) : nil
            }
            _ = press(&router, "ctrl+alt+space")
            let outcome = press(&router, chord)
            #expect(outcome == .passed(closing: true), "\(chord)")
            #expect(!outcome.swallows)
            #expect(!router.isOpen, "\(chord)")
        }
    }

    @Test("An app's menu chord stays swallowed")
    func appChordsSwallowed() {
        for chord in ["cmd+q", "cmd+w", "cmd+m", "cmd+h"] {
            var router = router()
            _ = press(&router, "ctrl+alt+space")
            #expect(press(&router, chord) == .unbound, "\(chord)")
            #expect(router.isOpen)
        }
    }

    @Test("A recorded step key wins over macOS's chord")
    func stepKeyWins() {
        var router = router(Self.stepOnScreenshot)
        _ = press(&router, "ctrl+alt+space")
        #expect(press(&router, "cmd+shift+4") == .fired(ref: 9))
    }

    @Test("A remapped shortcut passes on its new chord, not the old")
    func remappedChord() {
        let screenshot = SystemShortcut.screenshotSelection
        let id = screenshot.symbolicHotkey!.id
        // ⌃⌘4: character, key code, modifier mask.
        let moved = SymbolicHotkeyEntry(
            enabled: true,
            combo: SymbolicHotkeys.chord([52, kVK_ANSI_4, 0x14_0000])
        )
        var router = router { $0 == id ? moved : nil }
        _ = press(&router, "ctrl+alt+space")
        #expect(press(&router, "ctrl+cmd+4") == .passed(closing: false))
        _ = press(&router, "ctrl+alt+space")
        _ = press(&router, "ctrl+alt+space")
        #expect(press(&router, "cmd+shift+4") == .unbound)
    }

    @Test("A shortcut switched off in macOS stays swallowed")
    func switchedOffSwallowed() {
        let id = SystemShortcut.spotlight.symbolicHotkey!.id
        var router = router {
            $0 == id ? SymbolicHotkeyEntry(enabled: false) : nil
        }
        _ = press(&router, "ctrl+alt+space")
        #expect(press(&router, "cmd+space") == .unbound)
        // Zoom ships off: no entry, no pass.
        #expect(press(&router, "alt+cmd+8") == .unbound)
    }

    @Test("A plist modifier mask reads as the chord it names")
    func plistChord() {
        let combo = SymbolicHotkeys.chord([32, kVK_Space, 0x10_0000])
        #expect(combo == KeyCombo.parse("cmd+space"))
        #expect(SymbolicHotkeys.chord([65535, 65535, 0]) == nil)
    }

    @Test("A step key's warning reads the chord as the router does")
    @MainActor
    func stepWarningMatchesRouter() {
        let core = makeTestCore()
        #expect(core.sequenceStepTakes("cmd+shift+4") == .screenshotSelection)
        #expect(core.sequenceStepTakes("cmd+q") == nil)
        #expect(core.sequenceStepTakes("w") == nil)
        let id = SystemShortcut.screenshotSelection.symbolicHotkey!.id
        let moved = SymbolicHotkeys.chord([52, kVK_ANSI_4, 0x14_0000])
        core.keys.readSymbolicHotkey = {
            $0 == id ? SymbolicHotkeyEntry(enabled: true, combo: moved) : nil
        }
        // The read is taken once per arming.
        core.keys.answeredChords = nil
        #expect(core.sequenceStepTakes("cmd+shift+4") == nil)
        #expect(core.sequenceStepTakes("ctrl+cmd+4") == .screenshotSelection)
    }

    @Test("The tap swallows nothing it passed")
    func tapRecordsOnlyClosingPasses() {
        var state = SequenceTapState()
        let staying = state.record(.passed(closing: false))
        let closing = state.record(.passed(closing: true))
        #expect(!staying)
        #expect(closing)
    }
}
