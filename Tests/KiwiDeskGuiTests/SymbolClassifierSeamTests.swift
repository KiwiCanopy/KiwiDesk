import Foundation
import Testing

@testable import KiwiDesk

/// "Does this icon name an SF Symbol" is answered in ONE place,
/// `KiwiCore.iconIsSymbol` — a hand copy beside a drawing site is
/// how the Bars preview came to show a symbol's name as text
/// (#1538). The subject is the LOOKUP: every `systemSymbolName:`
/// in either tree is listed with what it does, so a new one reds
/// until a reader classifies it; two shape needles beside it
/// refuse a classifier inside a listed file — the nil-compare
/// the round-1 copies had, and the `if let` arm that drew a
/// layer icon's name and which the nil needle alone missed.
@Suite("Symbol classifier seam")
struct SymbolClassifierSeamTests {
    /// Repo-relative path → what its lookup does. Exact both
    /// ways: a stale entry reds too. "Builds" means the name was
    /// classified upstream or is the app's own fixed symbol.
    private let allowed: [String: String] = [
        "Sources/KiwiDeskCore/App/KiwiCore+SpaceBarItems.swift":
            "the one classifier, `KiwiCore.iconIsSymbol`",
        "Sources/KiwiDesk/StatusItemController+Icon.swift":
            "builds the status image; ⚠︎ when a fixed name fails",
        "Sources/KiwiDesk/StatusItemController.swift":
            "builds a template image from a fixed name",
        "Sources/KiwiDesk/StatusItemController+SpaceMark.swift":
            "builds the Space mark's image from a `.symbol` verdict",
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
        "Sources/KiwiDeskCore/Bar/ShelfCountView.swift":
            "builds the overflow count's chevron from a fixed name",
        "Tests/KiwiDeskCoreTests/ShelfCountTests.swift":
            "asserts every count chevron RESOLVES; classifies nothing",
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

    /// The other spelling of a classifier: binding the lookup with
    /// `if let` / `guard let` and drawing the NAME on the else arm
    /// — the status item's mode-icon arm once did (#1538). One
    /// render-time net may bind: `StickyMarkPlate` draws a name
    /// `homeSpaceMark` already classified.
    private let bindingAllowed: [String: String] = [
        "Sources/KiwiDeskCore/Borders/StickyMarkPlate.swift":
            "render-time net on a name `homeSpaceMark` classified"
    ]

    /// The nil-compared lookup, the shape every hand copy had —
    /// the lookup's own result against nil, not a bound variable
    /// later (the status item's ⚠︎ fallback). One assertion may
    /// spell it.
    private let nilCompareAllowed: [String: String] = [
        "Sources/KiwiDeskCore/App/KiwiCore+SpaceBarItems.swift":
            "the one classifier, `KiwiCore.iconIsSymbol`",
        "Tests/KiwiDeskCoreTests/ResizeRefusalSymbolTests.swift":
            "asserts every pill symbol resolves",
        "Tests/KiwiDeskCoreTests/ShelfCountTests.swift":
            "asserts every count chevron resolves",
    ]

    @Test("A nil-compared lookup lives in the classifier alone")
    func nilComparedLookupHasOneHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let compare = try Regex(
            #"systemSymbolName:[^;{}]{0,160}?\)\s*[!=]= nil"#
        )
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
                if source.contains(compare) {
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
            found == Set(nilCompareAllowed.keys),
            Comment(rawValue: found.sorted().joined(separator: ", "))
        )
    }

    @Test("No lookup is classified by binding it outside the one net")
    func classifyByBindingHasOneHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let binding = try Regex(
            #"(if|guard)\s+let\s+\w+\s*=\s*NSImage\(\s*systemSymbolName:"#
        )
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
                if source.contains(binding) {
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
            found == Set(bindingAllowed.keys),
            Comment(rawValue: found.sorted().joined(separator: ", "))
        )
    }
}
