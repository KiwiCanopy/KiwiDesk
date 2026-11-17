import KiwiDeskCore

/// A scroll chord as glyphs, Hyper's ✦ first, then the ⌃⌥⇧⌘
/// order, as `ChordGlyphs` draws a key chord (#3407).
enum ScrollChordGlyphs {
    static func symbols(_ chord: ScrollChord) -> [String] {
        var result: [String] = []
        if chord.contains(.hyper) { result.append(ComboSymbols.hyperGlyph) }
        if chord.contains(.control) { result.append("⌃") }
        if chord.contains(.option) { result.append("⌥") }
        if chord.contains(.shift) { result.append("⇧") }
        if chord.contains(.command) { result.append("⌘") }
        return result
    }

    /// The whole chord as one run of glyphs.
    static func text(_ chord: ScrollChord) -> String {
        symbols(chord).joined()
    }

    /// The chord as VoiceOver reads it: ✦ by its key's name, since
    /// the glyph reads as a star (#2700, #3407).
    @MainActor static func spoken(_ chord: ScrollChord) -> String {
        SidedChordWords.label(text(chord))
    }
}
