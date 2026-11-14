import Testing

@testable import KiwiDeskCore

/// The chord macOS answers for a shortcut (#3319, #3331): the
/// plist's bit and chord, else the shipped state and the map's
/// chord, and nothing for a cleared shortcut.
@Suite("A system shortcut's answered chord (#3319)")
struct AnsweredChordTests {
    private let other = SystemShortcut.inputSourcePrevious
    private let ctrlSpace = KeyCombo.parse("ctrl+space")!
    private let moved = KeyCombo.parse("ctrl+shift+space")!

    private func chord(_ entry: SymbolicHotkeyEntry?) -> KeyCombo? {
        other.answeredChord {
            $0 == other.symbolicHotkey?.id ? entry : nil
        }
    }

    @Test("absent, off, cleared and moved read as macOS answers them")
    func readsThePlist() {
        #expect(chord(nil) == ctrlSpace)
        #expect(chord(SymbolicHotkeyEntry(enabled: false)) == nil)
        #expect(
            chord(SymbolicHotkeyEntry(enabled: true, keyless: true)) == nil
        )
        #expect(
            chord(SymbolicHotkeyEntry(enabled: true, combo: moved)) == moved
        )
        #expect(chord(SymbolicHotkeyEntry(combo: moved)) == moved)
    }

    @Test("a hotkey that ships off answers nothing with no entry")
    func shipsOff() {
        let zoom = SystemShortcut.zoomToggle
        #expect(zoom.symbolicHotkey?.shipsEnabled == false)
        #expect(zoom.answeredChord { _ in nil } == nil)
    }

    @Test("a shortcut with no hotkey id answers its map chord")
    func acceleratorAlwaysAnswers() {
        let tab = KeyCombo.parse("cmd+tab")
        let off = SymbolicHotkeyEntry(enabled: false)
        #expect(SystemShortcut.appSwitcher.answeredChord { _ in off } == tab)
    }

    @Test("hotkey 60 ships on, on ⌃Space")
    func shippedChord() {
        #expect(other.symbolicHotkey?.id == 60)
        #expect(other.symbolicHotkey?.shipsEnabled == true)
        #expect(SystemShortcuts.chord(of: other) == ctrlSpace)
        #expect(SystemShortcuts.map[ctrlSpace] == other)
    }

    @Test("a cleared map shortcut is not passed to an open sequence")
    func clearedMapShortcutIsNotAnswered() {
        let spotlight = SystemShortcut.spotlight.symbolicHotkey!.id
        let answered = SystemShortcuts.answered {
            $0 == spotlight
                ? SymbolicHotkeyEntry(enabled: true, keyless: true) : nil
        }
        #expect(!answered.contains { $0.shortcut == .spotlight })
        #expect(answered.contains { $0.shortcut == .appSwitcher })
        let cleared = SymbolicHotkeyEntry(enabled: true, keyless: true)
        #expect(!SystemShortcut.spotlight.isAnswered(cleared))
        let chords = SequencePassChords.live {
            $0 == spotlight ? cleared : nil
        }
        let spotlightChord = SystemShortcuts.chord(of: .spotlight)
        #expect(spotlightChord != nil)
        #expect(!chords.closes.contains { $0 == spotlightChord })
        #expect(
            SequencePassChords.live { _ in nil }.closes
                .contains { $0 == spotlightChord }
        )
    }

    @Test("a plist entry naming no key reads as cleared")
    func parsesTheClearedEntry() {
        let cleared = SymbolicHotkeys.entry(from: [
            "enabled": true,
            "value": ["parameters": [65535, 65535, 0]],
        ])
        #expect(cleared.keyless)
        #expect(cleared.combo == nil)
        let set = SymbolicHotkeys.entry(from: [
            "enabled": true,
            "value": ["parameters": [32, 49, 262144]],
        ])
        #expect(!set.keyless)
        #expect(set.combo == KeyCombo.parse("ctrl+space"))
        #expect(!SymbolicHotkeys.entry(from: ["enabled": false]).keyless)
    }
}
