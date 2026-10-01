import Foundation
import Testing

/// `SourceScan.scopeTree` decides what a class-scoped scan SEES,
/// so it owes a whole-tree canary measured outside its walker
/// (tests.md ▸ source-scanning primitives): every class a plain
/// regex finds in both Sources trees must come back as a `class`
/// scope opening at the same brace. A walker that mis-names or
/// loses scopes would otherwise let a census pass for having
/// found no owner.
@Suite("SourceScan scope tree")
struct SourceScanScopesTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static let declaration = try! NSRegularExpression(
        pattern: #"\bclass\s+(\w+)[^{;=]*\{"#
    )
    private static let notTypes: Set<String> = [
        "func", "var", "let", "subscript",
    ]

    @Test("every class declaration in Sources is a class scope")
    func nothingGoesDark() throws {
        var seen = 0
        var dark: [String] = []
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
                for hit in Self.declaration.matches(
                    in: text as String,
                    range: NSRange(location: 0, length: text.length)
                ) {
                    let name = text.substring(with: hit.range(at: 1))
                    guard !Self.notTypes.contains(name) else { continue }
                    seen += 1
                    let brace = hit.range.location + hit.range.length - 1
                    let scope = byOpen[brace]
                    if scope?.keyword != "class" || scope?.name != name {
                        dark.append("\(file.lastPathComponent): \(name)")
                    }
                }
            }
        }
        #expect(seen > 100, "the regex found only \(seen) classes")
        #expect(dark.isEmpty, .init(rawValue: "unseen: \(dark)"))
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
