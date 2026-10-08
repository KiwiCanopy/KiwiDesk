import Foundation
import Testing

/// The chip tiers hold only if no caller steps around them (#2047):
/// a `.hoverHighlight(` call handing its own fills or edge, or a
/// hand-rolled hover fill of a hierarchical colour, paints a chip
/// no token and no contrast row can see.
@Suite("Chip tier call sites (#2047)")
struct ChipTierCallSiteTests {
    /// The tier definitions themselves, which are the one place the
    /// arguments are spelled. Keyed on the file's name, so a call
    /// added elsewhere in it would be exempt too.
    private let tierHome = "SettingsRows.swift"

    private func sources() throws -> [(name: String, text: String)] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        // A scan that read nothing would pass having looked at
        // nothing (#635).
        #expect(files.count > 50)
        return try files.map {
            (
                $0.lastPathComponent,
                SourceScan.stripComments(
                    try String(contentsOf: $0, encoding: .utf8)
                )
            )
        }
    }

    /// The text between a call's opening parenthesis and its
    /// matching close.
    private func arguments(
        of text: String,
        after open: String.Index
    ) -> String {
        var depth = 1
        var index = open
        while index < text.endIndex, depth > 0 {
            switch text[index] {
            case "(": depth += 1
            case ")": depth -= 1
            default: break
            }
            index = text.index(after: index)
        }
        return String(text[open..<index])
    }

    @Test("no hover chip call hands its own fills or edge")
    func callsTakeTheTier() throws {
        var calls = 0
        for (name, text) in try sources() where name != tierHome {
            var rest = text.startIndex
            while let hit = text.range(
                of: ".hoverHighlight(",
                range: rest..<text.endIndex
            ) {
                calls += 1
                let args = arguments(of: text, after: hit.upperBound)
                    .split(whereSeparator: \.isWhitespace).joined()
                for label in ["rest:", "hover:", "edge:"] {
                    #expect(
                        !args.contains(label),
                        Comment(rawValue: "\(name): \(label) \(args)")
                    )
                }
                rest = hit.upperBound
            }
        }
        // The button chips are callers; none found means the
        // needle went stale, not that the tree is clean.
        #expect(calls > 0)
    }

    /// A file whose hover fill is a ruled carve-out, and why.
    private let carveOut: [String: String] = [
        "SettingsRows.swift":
            "the full-row entry's 0.06 hover, kept as a named "
            + "carve-out from the chip tokens"
    ]

    /// A hierarchical colour's opacity with a hover state within
    /// reach is the faint fill #2047 retired, whichever control
    /// draws it — the chip tokens carry every hover lift.
    @Test("no hover fill is a bare hierarchical opacity")
    func noHierarchicalHoverFill() throws {
        let pattern = try Regex(
            #"\.(primary|secondary|tertiary)\.opacity\("#
        )
        for (name, text) in try sources() where carveOut[name] == nil {
            for match in text.matches(of: pattern) {
                let low =
                    text.index(
                        match.range.lowerBound,
                        offsetBy: -160,
                        limitedBy: text.startIndex
                    ) ?? text.startIndex
                let high =
                    text.index(
                        match.range.upperBound,
                        offsetBy: 80,
                        limitedBy: text.endIndex
                    ) ?? text.endIndex
                let window = text[low..<high].lowercased()
                #expect(
                    !window.contains("hover"),
                    Comment(
                        rawValue: "\(name) draws a hover fill as a "
                            + "hierarchical opacity — take the chip "
                            + "tokens (#2047)"
                    )
                )
            }
        }
    }
}
