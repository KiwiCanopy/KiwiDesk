import Foundation
import Testing

@testable import KiwiDesk

/// "Does this icon name an SF Symbol" is answered in ONE place,
/// `KiwiCore.iconIsSymbol` — a hand copy beside a drawing site is
/// how the Bars preview came to show a symbol's name as text
/// (#1538). The needle is the CONDITION, a symbol lookup whose
/// result is compared to nil, not a spelling: building an image
/// from a symbol is a different subject and stays out.
@Suite("Symbol classifier seam")
struct SymbolClassifierSeamTests {
    /// Repo-relative path → why a nil-compared lookup may live
    /// there. Exact both ways: a stale entry reds too.
    private let allowed: [String: String] = [
        "Sources/KiwiDeskCore/App/KiwiCore+SpaceBarItems.swift":
            "the one home, `KiwiCore.iconIsSymbol`",
        "Tests/KiwiDeskCoreTests/ResizeRefusalSymbolTests.swift":
            "asserts a pill symbol RESOLVES; classifies nothing",
        "Sources/KiwiDesk/StatusItemController+Icon.swift":
            "shows ⚠︎ when a fixed status symbol fails to build — "
            + "a fallback on the image, not a reading of an icon",
    ]

    @Test("A nil-compared symbol lookup has one home")
    func nilComparedLookupHasOneHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var found: Set<String> = []
        var scanned = 0
        for tree in ["Sources", "Tests"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            for file in files {
                scanned += 1
                let source = SourceScan.blankingCommentsAndLiterals(
                    try String(contentsOf: file, encoding: .utf8)
                )
                var cursor = source.startIndex
                while let hit = source.range(
                    of: "systemSymbolName:",
                    range: cursor..<source.endIndex
                ) {
                    cursor = hit.upperBound
                    let window = source[
                        hit
                            .upperBound..<(source.index(
                                hit.upperBound,
                                offsetBy: 160,
                                limitedBy: source.endIndex
                            ) ?? source.endIndex)
                    ]
                    if window.contains("!= nil")
                        || window.contains("== nil")
                    {
                        found.insert(
                            file.path.replacingOccurrences(
                                of: root.path + "/",
                                with: ""
                            )
                        )
                    }
                }
            }
        }
        #expect(scanned > 300)
        #expect(
            found == Set(allowed.keys),
            Comment(rawValue: found.sorted().joined(separator: ", "))
        )
        for (path, reason) in allowed {
            #expect(!reason.isEmpty, Comment(rawValue: path))
        }
    }
}
