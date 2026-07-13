import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("KeyCombo parsing")
struct KeyComboTests {
    @Test("comboString emits Mac words and round-trips")
    func comboStringRoundTrip() throws {
        let text = try #require(
            KeyCombo.comboString(
                keyCode: 15,
                command: false,
                option: true,
                control: true,
                shift: false
            )
        )
        #expect(text == "control+option+r")
        let parsed = try #require(KeyCombo.parse(text))
        #expect(parsed.modifiers == [.control, .option])
        #expect(parsed.keyCode == 15)
    }

    @Test("word aliases for punctuation keys parse")
    func punctuationAliases() throws {
        let combo = try #require(
            KeyCombo.parse("ctrl+alt+cmd+semicolon")
        )
        #expect(combo.keyCode == 41)
        #expect(
            combo.modifiers == [.control, .option, .command]
        )
        #expect(KeyCombo.parse("cmd+comma")?.keyCode == 43)
        #expect(KeyCombo.parse("alt+period")?.keyCode == 47)
        // The symbol form still works and matches the word.
        #expect(
            KeyCombo.parse("cmd+;")?.keyCode
                == KeyCombo.parse("cmd+semicolon")?.keyCode
        )
        // Display prefers the readable word form.
        #expect(
            KeyCombo.comboString(
                keyCode: 41,
                command: true,
                option: false,
                control: false,
                shift: false
            ) == "command+semicolon"
        )
    }

    @Test("comboString names disambiguate aliased codes")
    func comboStringNames() {
        #expect(
            KeyCombo.comboString(
                keyCode: 53,
                command: false,
                option: false,
                control: false,
                shift: false
            ) == "escape"
        )
        #expect(
            KeyCombo.comboString(
                keyCode: 36,
                command: true,
                option: false,
                control: false,
                shift: false
            ) == "command+return"
        )
    }

    @Test("Parses modifiers and key names")
    func parsing() throws {
        let combo = try #require(
            KeyCombo.parse("ctrl+alt+r")
        )
        #expect(combo.modifiers == [.control, .option])
        #expect(combo.keyCode == 15)

        let arrows = try #require(
            KeyCombo.parse("cmd+shift+left")
        )
        #expect(arrows.modifiers == [.command, .shift])
        #expect(arrows.keyCode == 123)
    }

    @Test("Single keys work for modal modes")
    func bareKey() throws {
        let combo = try #require(KeyCombo.parse("escape"))
        #expect(combo.modifiers == [])
        #expect(combo.keyCode == 53)
    }

    @Test("Authored aliases identify one physical combo")
    func aliasesAreEquivalent() {
        #expect(
            KeyCombo.equivalent("alt+j", "option+j")
        )
        #expect(
            KeyCombo.equivalent("cmd+;", "command+semicolon")
        )
        #expect(!KeyCombo.equivalent("alt+j", "alt+k"))
    }

    @Test("Rejects unknown keys and modifiers")
    func rejects() {
        #expect(KeyCombo.parse("hyper+x") == nil)
        #expect(KeyCombo.parse("cmd+notakey") == nil)
        #expect(KeyCombo.parse("") == nil)
    }
}
