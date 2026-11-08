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
}
