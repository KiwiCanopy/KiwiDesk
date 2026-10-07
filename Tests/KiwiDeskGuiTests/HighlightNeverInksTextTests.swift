import Foundation
import Testing

/// The gold's relaxed floor (#2038): `SettingsTheme.highlight` is
/// held to colour-vision separation rather than a text contrast
/// ratio (`HighlightSeparationTests`) ONLY because it marks and
/// never inks. So every use names the view it colours, and that
/// view is never text — the nearest view constructor before each
/// use is not a `Text(` or a `Label(`.
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
