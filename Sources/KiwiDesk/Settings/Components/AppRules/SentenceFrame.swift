import Foundation

/// Localized format string parsed into interleaved text and control slots.
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

    /// Supported control types mapped to argument positions.
    enum Control: Hashable {
        case appName
        case space
        case float
    }

    /// Resolves argument index to control type, returning nil if unmapped.
    static func control(at position: Int) -> Control? {
        switch position {
        case 1: return .appName
        case 2: return .space
        case 3: return .float
        default: return nil
        }
    }

    /// Controls referenced by frame in parsed appearance order.
    var controls: [Control] {
        argumentPositions.compactMap(Self.control(at:))
    }

    /// Argument slot indices referenced by the format string.
    var argumentPositions: [Int] {
        segments.compactMap {
            if case .argument(let index) = $0.slot { return index }
            return nil
        }
    }
}
