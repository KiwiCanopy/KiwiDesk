import Testing

@testable import KiwiDeskCore

/// A modifier tap's spelling, refusals and glyphs (#1872): the
/// chord's own string, so every row and Lua take one alike.
@Suite("Modifier tap combos (#1872)")
struct KeyComboTapTests {
    @Test("the three spellings parse and round-trip")
    func roundTrip() throws {
        let cases: [(String, Int, ModifierSide?)] = [
            ("cmd+cmd", 2, nil), ("ropt+ropt", 2, .right),
            ("rcmd", 1, .right), ("lshift", 1, .left),
            ("ctrl+ctrl", 2, nil),
        ]
        for (text, count, side) in cases {
            let combo = try #require(KeyCombo.parse(text), "\(text)")
            #expect(combo.tapCount == count, "\(text)")
            let kind = try #require(combo.tapKind)
            #expect(combo.modifiers.side(of: kind) == side, "\(text)")
            #expect(combo.comboString() == text, "\(text)")
            #expect(KeyCombo.parse(combo.comboString() ?? "") == combo)
        }
        #expect(KeyCombo.parse("command+command") == KeyCombo.parse("cmd+cmd"))
    }

    @Test("a single tap needs a side; mixed or hyper taps are refused")
    func refusals() {
        for text in [
            "cmd", "opt", "lcmd+rcmd", "cmd+rcmd", "cmd+cmd+cmd",
            "hyper", "hyper+hyper",
        ] {
            #expect(KeyCombo.parse(text) == nil, "\(text)")
        }
        #expect(KeyCombo.tap(.command, side: nil, count: 1) == nil)
        #expect(KeyCombo.tap(.command, side: .left, count: 3) == nil)
    }

    @Test("a tap is no chord: no key, and chords stay chords")
    func notAChord() throws {
        let chord = try #require(KeyCombo.parse("cmd+h"))
        #expect(!chord.isTap)
        #expect(chord.tapKind == nil)
        let tap = try #require(KeyCombo.parse("rcmd+rcmd"))
        #expect(KeyCombo.keyName(for: tap.keyCode) == nil)
    }

    @Test("a tap draws its modifier once per press")
    func glyphs() throws {
        let render = { (text: String) throws -> String in
            ComboSymbols.render(
                try #require(KeyCombo.parse(text)),
                layoutChar: { _ in "X" }
            )
        }
        #expect(try render("cmd+cmd") == "⌘⌘")
        #expect(try render("ropt+ropt") == "R⌥R⌥")
        #expect(try render("rcmd") == "R⌘")
    }

    @Test("taps a side tells apart never collapse; a twin is a dupe")
    func conflicts() {
        let row = { (id: String, combo: String) in
            KeyBinding(combo: combo, lua: "print(\"\(id)\")")
        }
        let either = row("a", "cmd+cmd")
        let right = row("b", "rcmd+rcmd")
        let left = row("c", "lcmd")
        let other = row("d", "rcmd")
        for sides in [false, true] {
            #expect(
                KeybindingConflicts.conflict(
                    for: either,
                    in: [either, right],
                    distinguishingSides: sides
                ) == nil
            )
            #expect(
                KeybindingConflicts.conflict(
                    for: left,
                    in: [left, other],
                    distinguishingSides: sides
                ) == nil
            )
        }
        let twin = row("e", "command+command")
        #expect(
            KeybindingConflicts.conflict(
                for: either,
                in: [either, twin],
                distinguishingSides: false
            )?
            .target == .otherBinding(twin)
        )
    }
}
