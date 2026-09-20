import Foundation
import Testing

@testable import KiwiDesk

/// "Does this icon name an SF Symbol" is answered in ONE place,
/// `KiwiCore.iconIsSymbol` — a hand copy beside a drawing site is
/// how the Bars preview came to show a symbol's name as text
/// (#1538). The subject is the LOOKUP: every `systemSymbolName:`
/// in either tree is listed with what it does, so a new one reds
/// until a reader classifies it — a needle on the nil-compare
/// shape missed the `if let` arm that drew a layer icon's name.
@Suite("Symbol classifier seam")
struct SymbolClassifierSeamTests {
    /// Repo-relative path → what its lookup does. Exact both
    /// ways: a stale entry reds too. "Builds" means the name was
    /// classified upstream or is the app's own fixed symbol.
    private let allowed: [String: String] = [
        "Sources/KiwiDeskCore/App/KiwiCore+SpaceBarItems.swift":
            "the one classifier, `KiwiCore.iconIsSymbol`",
        "Sources/KiwiDesk/StatusItemController+Icon.swift":
            "builds the status image; ⚠︎ when a fixed name fails, and "
            + "the mode-icon arm asks `iconIsSymbol` first",
        "Sources/KiwiDesk/StatusItemController.swift":
            "builds a template image from a fixed name",
        "Sources/KiwiDesk/StatusItemController+Updates.swift":
            "builds the updates row's image from a fixed name",
        "Sources/KiwiDeskCore/Bar/SpaceBarItemView+Style.swift":
            "builds the identifier image from a `.symbol` verdict",
        "Sources/KiwiDeskCore/Bar/StateBadgeView.swift":
            "builds a badge image from a fixed name",
        "Sources/KiwiDeskCore/Borders/StickyMarkOverlay.swift":
            "builds the sticky mark image from a fixed name",
        "Sources/KiwiDeskCore/Borders/StickyMarkPlate.swift":
            "render-time net on a name `homeSpaceMark` classified",
        "Sources/KiwiDeskCore/Borders/SizeLimitOverlay.swift":
            "builds the refusal pill's image from `pillSymbol`",
        "Tests/KiwiDeskCoreTests/ResizeRefusalSymbolTests.swift":
            "asserts every pill symbol RESOLVES; classifies nothing",
    ]

    @Test("Every symbol lookup is classified, and the classifier has one home")
    func everyLookupIsClassified() throws {
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
                if source.contains("systemSymbolName:") {
                    found.insert(
                        file.path.replacingOccurrences(
                            of: root.path + "/",
                            with: ""
                        )
                    )
                }
            }
        }
        #expect(scanned > 300)
        #expect(
            found == Set(allowed.keys),
            Comment(
                rawValue:
                    "unlisted: "
                    + found.subtracting(allowed.keys).sorted()
                    .joined(separator: ", ")
                    + "; stale: "
                    + Set(allowed.keys).subtracting(found).sorted()
                    .joined(separator: ", ")
            )
        )
        for (path, reason) in allowed {
            #expect(!reason.isEmpty, Comment(rawValue: path))
        }
    }
}
