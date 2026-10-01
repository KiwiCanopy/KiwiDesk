import Foundation
import Testing

/// `SourceScan.scopeTree` decides what a type-scoped scan SEES,
/// so it owes a whole-tree canary measured outside its walker
/// (tests.md ▸ source-scanning primitives), in both directions:
/// every type declaration a plain regex finds in both Sources
/// trees comes back as a scope of that keyword and name, opening
/// at the same brace, and every scope the tree calls a type opens
/// at a brace the regex found. A lost scope lets a census pass
/// for having found no owner; an invented one (`case .class:`)
/// hands a member to the wrong owner.
@Suite("SourceScan scope tree")
struct SourceScanScopesTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static let declaration = try! NSRegularExpression(
        pattern: #"\b(class|struct|enum|actor|extension|protocol)"#
            + #"\s+(\w+)[^{;]*\{"#
    )
    private static let notTypes: Set<String> = [
        "func", "var", "let", "subscript", "in", "case",
    ]

    @Test("every type declaration in Sources is its own scope")
    func nothingGoesDark() throws {
        var seen = 0
        var dark: [String] = []
        var invented: [String] = []
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: Self.root.appendingPathComponent(tree)
            )
            for file in files {
                let text =
                    SourceScan.blankingCommentsAndLiterals(
                        try SourceScan.rawSource(at: file)
                    ) as NSString
                let scopes = SourceScan.scopeTree(of: text).scopes
                let byOpen = Dictionary(
                    scopes.map { ($0.open, $0) },
                    uniquingKeysWith: { first, _ in first }
                )
                let hits = Self.declaration.matches(
                    in: text as String,
                    range: NSRange(location: 0, length: text.length)
                )
                let declared = Set(
                    hits.filter {
                        !Self.notTypes.contains(
                            text.substring(with: $0.range(at: 2))
                        )
                    }.map { $0.range.location + $0.range.length - 1 }
                )
                for scope in scopes
                where SourceScan.typeKeywords.contains(scope.keyword)
                    && !declared.contains(scope.open)
                {
                    invented.append(
                        "\(file.lastPathComponent): \(scope.keyword) "
                            + "'\(scope.name)'"
                    )
                }
                for hit in hits {
                    let keyword = text.substring(with: hit.range(at: 1))
                    let name = text.substring(with: hit.range(at: 2))
                    guard !Self.notTypes.contains(name) else { continue }
                    seen += 1
                    let brace = hit.range.location + hit.range.length - 1
                    let scope = byOpen[brace]
                    if scope?.keyword != keyword || scope?.name != name {
                        dark.append("\(file.lastPathComponent): \(name)")
                    }
                }
            }
        }
        #expect(seen > 500, "the regex found only \(seen) types")
        #expect(dark.isEmpty, .init(rawValue: "unseen: \(dark)"))
        #expect(
            invented.isEmpty,
            .init(rawValue: "not declared: \(invented)")
        )
    }

    @Test("an identifier is matched whole")
    func identifierIsWhole() {
        #expect(SourceScan.mentions(identifier: "panel", in: "panel?."))
        #expect(!SourceScan.mentions(identifier: "panel", in: "panels"))
        #expect(
            !SourceScan.mentions(identifier: "panel", in: "panelFrame")
        )
        #expect(!SourceScan.mentions(identifier: "panel", in: "_panel"))
    }
}
