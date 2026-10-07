import Foundation
import Testing

/// The gold's relaxed floor (#2038): `SettingsTheme.highlight` is
/// held to colour-vision separation rather than a text contrast
/// ratio (`HighlightSeparationTests`) ONLY because it marks and
/// never inks. So every use names the view it colours, and that
/// view is never text — the nearest view constructor before each
/// use is not a `Text(` or a `Label(`. Two spellings that would
/// slip past that reading are refused outright: the gold handed
/// to `.tint(`, which reaches every label beneath it, and a local
/// binding of it (`let gold = SettingsTheme.highlight`), whose
/// later uses this scan cannot follow. A CONTAINER holding both an
/// `Image` and a `Text` and coloured as a whole is left to review:
/// the nearest constructor is whichever was written last.
@Suite("Highlight gold never inks text (#2038)")
struct HighlightNeverInksTextTests {
    /// Repo-relative path → what the gold colours there. Exact
    /// both ways: a new user reds until it is classified.
    private let allowed: [String: String] = [
        "Sources/KiwiDesk/Updates/UpdateNotesGroups.swift":
            "the panel's edge, ★, wash and caution rule",
        "Sources/KiwiDesk/Updates/UpdateSpotlightRows.swift":
            "the spotlight rows' symbols",
    ]

    private static let use = "SettingsTheme.highlight"
    private static let views = [
        "Text(", "Label(", "Image(", "Rectangle(", "RoundedRectangle(",
        "Circle(", "Capsule(", "shape.",
    ]

    /// The modifier call the use is an argument of: the last
    /// `.name(` before it, across line breaks.
    private static let modifier = #"\.(\w+)\([^()]*$"#
    /// A binding whose value expression holds the use: `let`/`var`,
    /// a name, an optional type, `=`, then no statement boundary.
    private static let binding =
        #"\b(let|var)\s+\w+(\s*:\s*[\w.]+)?\s*=(?!=)[^;{}()]*$"#

    @Test("every gold use is classified and colours no text")
    func goldInksNoText() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let files = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk")
        )
        #expect(files.count > 100)
        var found: Set<String> = []
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            var cursor = source.startIndex
            while let hit = source.range(
                of: Self.use,
                range: cursor..<source.endIndex
            ) {
                cursor = hit.upperBound
                // `highlightWashOpacity` is a metric, not the ink.
                if let next = source[hit.upperBound...].first,
                    next.isLetter || next.isNumber || next == "_"
                {
                    continue
                }
                let path = file.path.replacingOccurrences(
                    of: root.path + "/",
                    with: ""
                )
                found.insert(path)
                let before = source[..<hit.lowerBound]
                let recent = String(before.suffix(300))
                if let call = recent.range(
                    of: Self.modifier,
                    options: .regularExpression
                ) {
                    #expect(
                        !recent[call].hasPrefix(".tint("),
                        Comment(
                            rawValue: "\(path): the gold as a tint "
                                + "inks every label beneath it"
                        )
                    )
                }
                #expect(
                    recent.range(
                        of: Self.binding,
                        options: .regularExpression
                    ) == nil,
                    Comment(
                        rawValue: "\(path): a binding of the gold "
                            + "hides its uses from this scan — "
                            + "spell SettingsTheme.highlight at each"
                    )
                )
                let nearest = Self.views.compactMap { view in
                    before.range(of: view, options: .backwards).map {
                        (view, $0.lowerBound)
                    }
                }
                .max { $0.1 < $1.1 }?.0
                #expect(
                    nearest != "Text(" && nearest != "Label(",
                    Comment(
                        rawValue:
                            "\(path): the gold colours a "
                            + "\(nearest ?? "?") — it marks and never "
                            + "inks; a text in gold owes the 4.5:1 "
                            + "floor the gold was ruled out of"
                    )
                )
            }
        }
        #expect(found == Set(allowed.keys))
    }
}
