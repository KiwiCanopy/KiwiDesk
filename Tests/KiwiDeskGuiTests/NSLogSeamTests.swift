import Foundation
import Testing

/// No source line logs through `NSLog` (#2835): macOS redacts an
/// `NSLog` line's content to `<private>` in `log show`, so the
/// diagnostic fires and a capture reads nothing. A line writes
/// through an `os.Logger` with a `privacy: .public` interpolation
/// (core-boundaries.md ▸ the log seam). Scans every target under
/// `Sources/`, comments and literals stripped. The needle is the
/// bare identifier, so `NSLogv` and a spaced `NSLog (` red too.
@Suite("No NSLog in the sources (#2835)")
struct NSLogSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("no source file calls NSLog")
    func noNSLog() throws {
        let trees = SourceScan.targetTrees(
            under: Self.root.appendingPathComponent("Sources")
        )
        #expect(trees.count >= 2, "both source targets are walked")
        let sites = try trees.flatMap {
            try SourceScan.identifierSites(of: "NSLog", under: $0)
        }
        // The walk reaches real code: the loggers that replaced it.
        let loggers = try trees.flatMap {
            try SourceScan.identifierSites(of: "Logger(", under: $0)
        }
        #expect(!loggers.isEmpty)
        #expect(
            sites.isEmpty,
            .init(rawValue: sites.map(\.site).joined(separator: ", "))
        )
    }
}
