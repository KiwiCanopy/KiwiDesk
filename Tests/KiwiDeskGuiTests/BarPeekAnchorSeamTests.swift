import Foundation
import Testing

/// Who anchors the hover peek (#1946), split from
/// `BarPeekSeamTests` for the file size: every view that reports
/// the pointer to the peek, and every anchor each one hands it.
@Suite("Bar hover peek anchors (#1946)")
struct BarPeekAnchorSeamTests {
    private static var bar: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Bar")
    }

    /// Every view that reports the pointer to the peek, and the
    /// views it may hand as the anchor — the one copy of who
    /// anchors it. Derived from the `peek?.pointer(` callers, so a
    /// new reporter reds until it is written here; a reporter
    /// gaining an anchor (#1945's collapsed chip) widens its set.
    private static let anchors: [String: Set<String>] = [
        "SpaceBarItemView+Hover.swift": [
            "SpaceBarGlyphTarget.swift", "SpaceBarItemView.swift",
        ],
        "AppBarItemView+HoverTitle.swift": ["AppBarItemView.swift"],
    ]

    @Test("every anchor reports the pointer from the listed files")
    func anchorsAreListed() throws {
        var reporters: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.bar) {
            let text = try SourceScan.strippedSource(at: file)
            if text.contains("peek?.pointer(") {
                reporters.insert(file.lastPathComponent)
            }
        }
        #expect(reporters == Set(Self.anchors.keys), "\(reporters)")
    }

    /// What each reporter hands as the anchor, resolved to the
    /// file of the view's type: the `on:` argument of its
    /// `pointer(` call, or — where that forwards a parameter — the
    /// first argument of every `reportPeek(` call in the file. An
    /// expression `anchorFile` cannot resolve reds, so a new
    /// anchor is written into `anchors` rather than slipping past.
    @Test("every reporter hands the anchors listed for it")
    func anchorValuesAreListed() throws {
        for file in try SourceScan.swiftSources(under: Self.bar) {
            let name = file.lastPathComponent
            guard let listed = Self.anchors[name] else { continue }
            let text = try SourceScan.strippedSource(at: file)
            let args = try #require(
                SourceScan.callArguments(of: "peek?.pointer(", in: text)
            )
            let on = try #require(
                SourceScan.topLevelArguments(of: args)
                    .map(Self.trimmed)
                    .first { $0.hasPrefix("on:") }
            )
            var handed = [Self.trimmed(String(on.dropFirst(3)))]
            if handed == ["anchor"] {
                handed = SourceScan.firstArguments(
                    of: "reportPeek(",
                    in: text
                ).filter { !$0.contains(":") }
            }
            let own = String(name.prefix { $0 != "+" }) + ".swift"
            var derived: Set<String> = []
            for expression in handed {
                let resolved = Self.anchorFile(expression, own: own)
                #expect(resolved != nil, "\(name): \(expression)")
                if let resolved { derived.insert(resolved) }
            }
            #expect(derived == listed, "\(name): \(derived)")
        }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The view type an anchor expression names, as its file.
    private static func anchorFile(
        _ expression: String,
        own: String
    ) -> String? {
        let bare = trimmed(expression)
            .replacingOccurrences(of: "ownsPointer ? ", with: "")
            .replacingOccurrences(of: " : nil", with: "")
        switch bare {
        case "self": return own
        case "peeked": return "SpaceBarGlyphTarget.swift"
        default: return nil
        }
    }
}
