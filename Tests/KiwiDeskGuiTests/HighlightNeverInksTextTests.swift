import Foundation
import Testing

/// The gold's relaxed floor (#2038): `SettingsTheme.highlight` is
/// held to colour-vision separation rather than a text contrast
/// ratio (`HighlightSeparationTests`) ONLY because it marks and
/// never inks. So the gold is legal only in the two files listed
/// below, and only as the DIRECT argument of a mark modifier —
/// `.foregroundStyle(`, `.fill(`, `.stroke(`, `.strokeBorder(` —
/// whose nearest view constructor is not a `Text(` or a `Label(`.
/// Every other enclosing construct is refused: `.tint(`, which
/// reaches every label beneath it; a wrapper such as
/// `Color(SettingsTheme.highlight)`; and any binding or computed
/// alias (`let gold = …`, `static var kiwiGold: Color { … }`),
/// whose later uses this scan cannot follow. A CONTAINER holding
/// both an `Image` and a `Text` and coloured as a whole is left to
/// review: the nearest constructor is whichever was written last.
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

    /// The modifier calls the gold may be the direct argument of.
    private static let marks: Set<String> = [
        "foregroundStyle", "fill", "stroke", "strokeBorder",
    ]
    /// The call the use is the direct argument of: the last
    /// `.name(` before it with no paren between, across line
    /// breaks. A use inside `Color(…)` or a `{ … }` body has none.
    private static let enclosing = #"\.(\w+)\([^(){}]*$"#

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
                let call = recent.range(
                    of: Self.enclosing,
                    options: .regularExpression
                )
                .map { String(recent[$0].dropFirst().prefix { $0 != "(" }) }
                #expect(
                    call.map(Self.marks.contains) == true,
                    Comment(
                        rawValue: "\(path): the gold sits in "
                            + "\(call ?? "no modifier") — it is legal "
                            + "only as the direct argument of "
                            + "\(Self.marks.sorted()), so a tint, a "
                            + "wrapper or an alias cannot carry it "
                            + "onto text"
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
