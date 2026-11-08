import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A modifier tap as the GUI draws and says it (#1872 ▸ Ruling):
/// `⌘⌘`, `Right ⌥⌥`, `Right ⌘`, spoken "Command, press twice".
@Suite("Modifier tap drawing and words (#1872)")
@MainActor
struct ModifierTapWordsTests {
    private func combo(_ text: String) throws -> KeyCombo {
        try #require(KeyCombo.parse(text))
    }

    @Test("a tap draws as its glyph per press, the side said once")
    func drawn() throws {
        LocalizationManager.shared.select("en")
        let draw = { (text: String) throws -> String in
            ChordGlyphs.render(try self.combo(text), layoutChar: { _ in nil })
        }
        #expect(try draw("cmd+cmd") == "⌘⌘")
        #expect(try draw("ropt+ropt") == "Right ⌥⌥")
        #expect(try draw("rcmd") == "Right ⌘")
    }

    @Test("a tap says its modifier and how many presses")
    func spoken() throws {
        LocalizationManager.shared.select("en")
        #expect(
            ModifierTapWords.spoken(try combo("cmd+cmd"))
                == "Command, press twice"
        )
        #expect(
            ModifierTapWords.spoken(try combo("ropt+ropt"))
                == "Right Option, press twice"
        )
        #expect(
            ModifierTapWords.spoken(try combo("rcmd"))
                == "Right Command, press once"
        )
        #expect(ModifierTapWords.spoken(try combo("cmd+h")) == nil)
    }

    @Test("the wait names the double tap one more press records")
    func tapAgain() throws {
        LocalizationManager.shared.select("en")
        let single = try combo("rcmd")
        #expect(
            ModifierTapWords.tapAgain(single, sidesKept: false)
                == "Tap again for ⌘⌘"
        )
        #expect(
            ModifierTapWords.tapAgain(single, sidesKept: true)
                == "Tap again for Right ⌘⌘"
        )
    }

    @Test("every chord surface speaks a drawn double tap in words")
    func sharedDoorSpeaksDoubles() {
        LocalizationManager.shared.select("en")
        #expect(SidedChordWords.label("⌘⌘") == "Command, press twice")
        #expect(
            SidedChordWords.label("Right ⌥⌥")
                == "Right Option, press twice"
        )
        // A single sided glyph is also a modifier-layer chip, so
        // the shared door leaves it as a chord.
        let chip = SidedChordWords.spoken("Right ⌘")
        #expect(chip?.contains("press") == false)
        #expect(SidedChordWords.spoken("⌘⌥") == nil)
    }

    @Test("a tap row carries no either-side hint, a sided chord does")
    func noEitherSideHintOnTaps() {
        LocalizationManager.shared.select("en")
        let hint = { (combo: String) in
            KeyRecorderField.rowHint(
                combo: combo,
                sidesOn: false,
                recording: false,
                hyperDormant: false
            )
        }
        #expect(hint("rcmd") == nil)
        #expect(hint("ropt+ropt") == nil)
        #expect(hint("rcmd+h") != nil)
    }

    @Test("the keyboard board leaves taps out")
    func boardSkipsTaps() {
        let layer = KeyLayer(
            name: "default",
            bindings: [
                KeyBinding(combo: "cmd+cmd", lua: "print(1)"),
                KeyBinding(combo: "cmd+h", lua: "print(2)"),
            ]
        )
        #expect(
            KeyboardCensus.combos(in: [layer]) == [KeyCombo.parse("cmd+h")]
        )
    }
}
