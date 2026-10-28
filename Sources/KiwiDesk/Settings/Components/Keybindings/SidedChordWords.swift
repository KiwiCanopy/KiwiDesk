import Foundation
import KiwiDeskCore

/// A drawn chord as words (#2601 ▸ Ruling 1, amended): each sided
/// run `ChordGlyphs` drew — `Izq. ⌃⌥ J`, `左⌘H` — read back as the
/// Hyper card's full key names ("⌃ izquierdo ⌥ izquierdo J"), so
/// VoiceOver and the hover say a short catalog word in full. Reads
/// the run through the catalog's own side frame, never a second
/// spelling of it.
@MainActor
enum SidedChordWords {
    /// `drawn` with each sided run named key by key, or nil where
    /// no run keeps a side — that chord reads as drawn.
    static func spoken(_ drawn: String) -> String? {
        let frames = ModifierSide.allCases.map { side in
            (side, frame(side))
        }
        var rest = Substring(drawn)
        var words: [String] = []
        var sided = false
        scan: while !rest.isEmpty {
            rest = rest.drop { $0 == " " }
            for (side, frame) in frames {
                if let (run, tail) = match(frame, in: rest) {
                    words += run.compactMap { glyph in
                        ChordGlyphs.kinds[glyph].map {
                            HyperKeyWords.name(.key(side, of: $0))
                        }
                    }
                    rest = tail
                    sided = true
                    continue scan
                }
            }
            let token = rest.prefix { $0 != " " }
            words.append(String(token))
            rest = rest.dropFirst(token.count)
        }
        return sided ? words.joined(separator: " ") : nil
    }

    /// The words for `drawn`, or the drawn glyphs where none keep a
    /// side — what a label or value takes. ✦ is always its key's
    /// name, since VoiceOver reads the glyph as a star (#2700).
    static func label(_ drawn: String) -> String {
        let hyper = ComboSymbols.hyperGlyph
        let name = HyperKeyWords.keyName + " "
        return (spoken(drawn) ?? drawn)
            .replacingOccurrences(of: hyper + " ", with: name)
            .replacingOccurrences(of: hyper, with: name)
            .trimmingCharacters(in: .whitespaces)
    }

    /// The hover text a sided chord owes, empty for any other.
    static func help(_ drawn: String) -> String {
        spoken(drawn) ?? ""
    }

    /// The catalog's frame for `side`, split around its run.
    private static func frame(_ side: ModifierSide) -> (
        prefix: String, suffix: String
    ) {
        let marker = "\u{1}"
        let parts = ChordGlyphs.word(side, marker)
            .components(separatedBy: marker)
        return (parts.first ?? "", parts.count > 1 ? parts[1] : "")
    }

    /// A run of modifier glyphs `frame` wraps at the head of
    /// `text`, and what follows it.
    private static func match(
        _ frame: (prefix: String, suffix: String),
        in text: Substring
    ) -> (run: String, tail: Substring)? {
        guard !(frame.prefix.isEmpty && frame.suffix.isEmpty),
            text.hasPrefix(frame.prefix)
        else { return nil }
        let afterPrefix = text.dropFirst(frame.prefix.count)
        let run = afterPrefix.prefix { ChordGlyphs.kinds[$0] != nil }
        guard !run.isEmpty else { return nil }
        let afterRun = afterPrefix.dropFirst(run.count)
        guard afterRun.hasPrefix(frame.suffix) else { return nil }
        return (String(run), afterRun.dropFirst(frame.suffix.count))
    }
}
