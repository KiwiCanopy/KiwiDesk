import Testing

@testable import KiwiDeskCore

@Suite("ComboSymbols native glyph rendering")
struct ComboSymbolsTests {
    /// A US-layout stand-in: printable keys resolve to their US
    /// glyph, everything else (arrows, F-keys) returns nil so the
    /// fixed-glyph path is exercised.
    private func usLayout(_ code: UInt32) -> String? {
        KeyCombo.keyName(for: code).map(ComboSymbols.fallbackGlyph)
    }

    private func render(_ text: String) -> String {
        let combo = KeyCombo.parse(text)!
        return ComboSymbols.render(combo, layoutChar: usLayout)
    }

    @Test("Modifiers render in canonical ⌃⌥⇧⌘ order, Command last")
    func modifierOrder() {
        #expect(
            ComboSymbols.modifierSymbols(
                [.command, .shift, .option, .control]
            ) == "⌃⌥⇧⌘"
        )
    }

    @Test("Command+Shift+comma is ⇧⌘, with no separator")
    func glyphCombo() {
        #expect(render("command+shift+comma") == "⇧⌘,")
    }

    @Test("A bare letter uppercases; digits stay")
    func letterAndDigit() {
        #expect(render("command+a") == "⌘A")
        #expect(render("control+1") == "⌃1")
    }

    @Test("Punctuation words render as their glyph")
    func punctuation() {
        #expect(render("command+slash") == "⌘/")
        #expect(render("command+grave") == "⌘`")
    }

    @Test("Arrows and function keys use fixed symbols")
    func specialKeys() {
        #expect(render("control+option+left") == "⌃⌥←")
        #expect(render("command+f1") == "⌘F1")
        #expect(render("shift+space") == "⇧␣")
    }

    @Test("The + key shows as + with no combinator ambiguity")
    func plusKey() {
        // On a US layout the equal key shifted is "+", but the
        // stored base key is "equal"; a layout that maps it to "+"
        // must still be unambiguous — no separator precedes it.
        #expect(
            ComboSymbols.render(
                KeyCombo.parse("command+equal")!,
                layoutChar: { _ in "+" }
            ) == "⌘+"
        )
    }

    @Test("Locale glyph comes from the injected layout")
    func localeMapping() {
        // A German layout renders the US "]" key (code 30) as "+".
        let german: (UInt32) -> String? = { code in
            code == 30 ? "+" : self.usLayout(code)
        }
        let combo = KeyCombo.parse("shift+rightbracket")!
        #expect(ComboSymbols.render(combo, layoutChar: german) == "⇧+")
    }
}

/// The capitalisation rule, which every combo-rendering surface
/// shares — the recorder, the Shortcuts list, the draft diff rows
/// and the quick menu all reach it through `render`.
@Suite("Combo glyph capitalisation")
struct ComboGlyphCapitalisationTests {

    @Test("A key whose capital is two letters keeps its own form")
    func multiCharacterUppercaseIsRefused() {
        // The defect: German ß uppercases to "SS", so a shortcut
        // on that key rendered as ⌃⌥SS — two characters for one
        // key the keyboard prints as one.
        #expect("ß".uppercased() == "SS")
        #expect(ComboSymbols.capitalisedGlyph("ß") == "ß")
    }

    @Test("An ordinary letter still capitalises")
    func singleCharacterUppercaseIsKept() {
        #expect(ComboSymbols.capitalisedGlyph("a") == "A")
        #expect(ComboSymbols.capitalisedGlyph("ü") == "Ü")
        #expect(ComboSymbols.capitalisedGlyph("7") == "7")
    }

    @Test("The rendered combo carries the key's own form")
    func renderKeepsTheKeysOwnForm() {
        let combo = KeyCombo(keyCode: 27, modifiers: [.control])
        let rendered = ComboSymbols.render(combo) { _ in "ß" }
        #expect(rendered == "⌃ß")
        #expect(!rendered.contains("SS"))
    }
}
