import Testing

@testable import KiwiDeskCore

/// The chord macOS answers for a symbolic hotkey KiwiDesk names
/// outside `SystemShortcut` (#3319): the plist's bit and chord, else
/// the shipped state and chord, and nothing for a cleared shortcut.
@Suite("A symbolic hotkey's answered chord (#3319)")
struct AnsweredChordTests {
    private let other = SymbolicHotkeys.previousInputSource
    private let moved = KeyCombo.parse("ctrl+shift+space")!

    private func chord(_ entry: SymbolicHotkeyEntry?) -> KeyCombo? {
        SymbolicHotkeys.answeredChord(of: other) {
            $0 == other.id ? entry : nil
        }
    }

    @Test("absent, off, cleared and moved read as macOS answers them")
    func readsThePlist() {
        #expect(chord(nil) == other.chord)
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
        let off = ShippedHotkey(
            id: other.id,
            shipsEnabled: false,
            chord: other.chord
        )
        #expect(SymbolicHotkeys.answeredChord(of: off) { _ in nil } == nil)
    }

    @Test("the shipped chord is ⌃Space")
    func shippedChord() {
        #expect(other.id == 60)
        #expect(other.chord == KeyCombo.parse("ctrl+space"))
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
