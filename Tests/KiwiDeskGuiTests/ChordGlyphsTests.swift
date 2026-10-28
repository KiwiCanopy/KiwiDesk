import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A sided chord is drawn with its side as a word, said once per
/// run of same-side modifiers (#2601 ▸ Ruling, amended 2026-10-28):
/// `Left ⌃⌥ J`, never `L⌃L⌥J`, and an either-side chord unchanged.
@Suite("Chord glyphs name a side in words (#2601)")
@MainActor
struct ChordGlyphsTests {
    private func drawn(_ combo: String) throws -> String {
        ChordGlyphs.render(
            try #require(KeyCombo.parse(combo)),
            layoutChar: { _ in nil }
        )
    }

    @Test("a same-side run is named once")
    func runIsNamedOnce() throws {
        LocalizationManager.shared.select("en")
        #expect(try drawn("lctrl+lalt+j") == "Left ⌃⌥ J")
        #expect(try drawn("rcmd+h") == "Right ⌘ H")
    }

    @Test("a cross-hand chord names each run")
    func crossHandNamesEach() throws {
        LocalizationManager.shared.select("en")
        #expect(try drawn("lctrl+ralt+j") == "Left ⌃ Right ⌥ J")
    }

    @Test("an either-side modifier stays a bare glyph beside a run")
    func mixedKeepsTheBareGlyph() throws {
        LocalizationManager.shared.select("en")
        #expect(
            ChordGlyphs.modifiers(
                [.control, .option, .side(.right, of: .option)]
            ) == "⌃ Right ⌥"
        )
        #expect(
            ChordGlyphs.modifiers(
                [.hyper, .command, .side(.right, of: .command)]
            ) == "✦ Right ⌘"
        )
    }

    @Test("an either-side chord is drawn as Core draws it")
    func eitherSideUnchanged() throws {
        #expect(try drawn("ctrl+alt+j") == "⌃⌥J")
        #expect(try drawn("hyper+cmd+k") == "✦⌘K")
        #expect(ChordGlyphs.separator(.command).isEmpty)
    }

    @Test("the words come from the catalog, never a fixed language")
    func wordsAreLocalized() throws {
        defer { LocalizationManager.shared.select("en") }
        LocalizationManager.shared.select("ja")
        let japanese = try drawn("rcmd+h")
        LocalizationManager.shared.select("en")
        #expect(japanese != (try drawn("rcmd+h")))
        #expect(!japanese.contains("Right"))
    }

    /// The fold and the tour drop `modifiers + separator` off a
    /// drawn chord, so the three must agree for every side of every
    /// modifier, or a key loses its first character.
    @Test("a chord starts with its drawn modifiers and separator")
    func partsAgreeWithTheChord() throws {
        LocalizationManager.shared.select("en")
        for kind in ModifierKind.allCases {
            for side in [nil] + ModifierSide.allCases.map(Optional.some) {
                var modifiers = kind.plain
                if let side { modifiers.formUnion(.side(side, of: kind)) }
                let combo = KeyCombo(keyCode: 38, modifiers: modifiers)
                let drawn = ChordGlyphs.render(combo, layoutChar: { _ in "J" })
                let head =
                    ChordGlyphs.modifiers(modifiers)
                    + ChordGlyphs.separator(modifiers)
                #expect(drawn == head + "J", "\(drawn)")
            }
        }
    }
}
