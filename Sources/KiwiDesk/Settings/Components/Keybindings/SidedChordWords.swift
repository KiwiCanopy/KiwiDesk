import KiwiDeskCore

/// A sided chord as words (#2601 ▸ Ruling 1): `R⌘H` is drawn with a
/// bare letter VoiceOver reads as one, so every surface drawing a
/// chord speaks and explains it through here, naming each side with
/// the Hyper card's own key names ("Right ⌘ H").
@MainActor
enum SidedChordWords {
    /// The chord drawn as `glyphs` (`ComboSymbols`), each modifier a
    /// word, or nil where no modifier keeps a side — that chord reads
    /// as drawn. `ComboSymbols` puts a side letter only before its
    /// modifier's glyph, so a letter before a glyph is a side.
    static func spoken(_ glyphs: String) -> String? {
        let chars = Array(glyphs)
        let kinds = Self.kinds
        let sides = Self.sides
        var words: [String] = []
        var index = 0
        var sided = false
        while index < chars.count {
            let char = chars[index]
            if kinds[char] != nil
                || String(char) == ComboSymbols.hyperGlyph
            {
                words.append(String(char))
                index += 1
            } else if let side = sides[char], index + 1 < chars.count,
                let kind = kinds[chars[index + 1]]
            {
                words.append(HyperKeyWords.name(.key(side, of: kind)))
                sided = true
                index += 2
            } else {
                break
            }
        }
        guard sided else { return nil }
        let key = String(chars[index...])
        return (words + (key.isEmpty ? [] : [key])).joined(separator: " ")
    }

    /// The words for `glyphs`, or the drawn glyphs where none keep a
    /// side — what a label or value takes.
    static func label(_ glyphs: String) -> String {
        spoken(glyphs) ?? glyphs
    }

    /// The hover text a sided chord owes, empty for any other.
    static func help(_ glyphs: String) -> String {
        spoken(glyphs) ?? ""
    }

    /// Read off Core's own glyph table, never a second spelling.
    private static var kinds: [Character: ModifierKind] {
        Dictionary(
            uniqueKeysWithValues: ModifierKind.allCases.map {
                (Character(ComboSymbols.glyph(of: $0)), $0)
            }
        )
    }

    private static var sides: [Character: ModifierSide] {
        Dictionary(
            uniqueKeysWithValues: ModifierSide.allCases.map {
                (Character(ComboSymbols.sideLetter($0)), $0)
            }
        )
    }
}
