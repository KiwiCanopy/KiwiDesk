import Foundation

/// Localized format string parsed into interleaved text and
/// argument slots.
///
/// The word order is the TRANSLATOR's: a sentence with controls
/// in it is ONE localized frame with positional specifiers, split
/// on those specifiers and emitted in whatever order the
/// translation put them — never connectives authored as their own
/// keys between fixed stack positions, which no catalog can
/// reorder and which this app's four verb-final locales cannot
/// render grammatically.
///
/// The App Rules row drew through this until #1022 reverted it to
/// labelled facets, which took the slot-to-control mapping with
/// it. The keyboard preview's layout sentence is the remaining
/// consumer, and the next surface that wants a sentence inherits
/// the splitter and `SentenceFrameTests`.
struct SentenceFrame {
    /// Literal text chunk or argument position.
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

    /// Argument slot indices referenced by the format string.
    var argumentPositions: [Int] {
        segments.compactMap {
            if case .argument(let index) = $0.slot { return index }
            return nil
        }
    }
}
