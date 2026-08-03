import Foundation

/// A localized sentence whose arguments are CONTROLS, split
/// into the pieces a view lays out in the translation's own
/// order.
///
/// `L(key, english, args…)` covers the ordinary case: the
/// arguments are strings, `String(format:)` places them, and a
/// translator moves `%2$@` before `%1$@` freely. A menu is not
/// a string, so a row that wants "Spotify opens in media ▾ and
/// floats ▾" cannot format its way there — and the tempting
/// alternative, emitting the connectives as their own keys
/// between fixed stack positions, is exactly what
/// `.claude/rules/localization.md` bans: a translation cannot
/// reorder pieces stitched together in Swift, and this app
/// ships ja, ko, zh-Hans and zh-Hant, where a verb-final
/// language cannot render "opens in" as anything that sits
/// where an English stack puts it.
///
/// So the frame stays one key with positional specifiers, and
/// this splits it into literal text and argument slots **in the
/// order the translation wrote them**. The view then draws its
/// controls at the slots, which is the same contract
/// `String(format:)` offers, with views instead of strings.
///
/// Unrecognized specifiers are kept as literal text rather than
/// dropped: a catalog carrying `%4$@` for a frame with three
/// arguments is a translation bug, and showing it is how it gets
/// noticed instead of silently losing a word.
struct SentenceFrame {
    /// One piece of the sentence: literal words, or the slot
    /// where argument *n* goes.
    enum Slot: Hashable {
        case text(String)
        case argument(Int)
    }

    struct Segment: Identifiable, Hashable {
        let id: Int
        let slot: Slot
    }

    let segments: [Segment]

    init(_ format: String) {
        var segments: [Segment] = []
        var literal = ""
        var rest = Substring(format)

        func flushLiteral() {
            guard !literal.isEmpty else { return }
            segments.append(
                Segment(id: segments.count, slot: .text(literal))
            )
            literal = ""
        }

        while let percent = rest.firstIndex(of: "%") {
            literal += rest[rest.startIndex..<percent]
            rest = rest[rest.index(after: percent)...]
            // `%n$@` — the only shape the localization rules
            // allow, so anything else is literal text.
            let digits = rest.prefix { $0.isNumber }
            let after = rest.dropFirst(digits.count)
            if let index = Int(digits), after.hasPrefix("$@") {
                flushLiteral()
                segments.append(
                    Segment(
                        id: segments.count,
                        slot: .argument(index)
                    )
                )
                rest = after.dropFirst(2)
            } else {
                literal += "%"
            }
        }
        literal += rest
        flushLiteral()
        self.segments = segments
    }

    /// The argument positions the frame actually uses, so a
    /// guard can hold a translation to the slots its view draws
    /// rather than trusting the catalog.
    var argumentPositions: [Int] {
        segments.compactMap {
            if case .argument(let index) = $0.slot { return index }
            return nil
        }
    }
}
