import Foundation
import Testing

/// `SourceScan.targetTrees(under:)` is what every tree-walking
/// guard scans, so an empty or partial answer would let each of
/// them pass as "no strays". This suite derives the expected
/// answer from `Package.swift`'s own `path:` declarations — the
/// one authority on which directories are targets — rather than
/// pinning a count (rule-authoring.md: derive the number).
@Suite("Target trees match Package.swift")
struct TargetTreeParityTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Every `path: "…"` a target declares, relative to the root.
    private func declaredPaths() throws -> Set<String> {
        let manifest = try String(
            contentsOf: Self.root.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let pattern = try NSRegularExpression(
            pattern: #"path:\s*"([^"]+)""#
        )
        let range = NSRange(manifest.startIndex..., in: manifest)
        let paths = pattern.matches(in: manifest, range: range)
            .compactMap { match in
                Range(match.range(at: 1), in: manifest)
                    .map { String(manifest[$0]) }
            }
        try #require(!paths.isEmpty, "no target paths parsed")
        return Set(paths)
    }

    @Test(
        "The derived trees are exactly the declared targets",
        arguments: ["Sources", "Tests"]
    )
    func derivedTreesMatchDeclaredTargets(parent: String) throws {
        let declared = try declaredPaths()
            .filter { $0.hasPrefix(parent + "/") }
        let derived = Set(
            SourceScan.targetTrees(
                under: Self.root.appendingPathComponent(parent)
            )
            .map { parent + "/" + $0.lastPathComponent }
        )
        #expect(!declared.isEmpty)
        #expect(derived == declared)
    }
}
