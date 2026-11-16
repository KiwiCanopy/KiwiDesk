import KiwiDeskCore

/// A scroll chord as glyphs, in the ⌃⌥⇧⌘ order.
enum ScrollChordGlyphs {
    static func symbols(_ chord: ScrollChord) -> [String] {
        var result: [String] = []
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
}
