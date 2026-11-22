import Foundation
import Testing

/// A layout's own App Bar visibility is written through the one
/// clearing door, `TilingSettings.setAppBarVisibility(_:in:)`, so
/// every pick of it clears the areas' App Bar values (#3517 ruling
/// 32). Both trees are scanned for a direct `.appBar.visibility =`
/// write or a two-way `$….appBar.visibility` binding; a hit outside
/// `allowed` reds until it routes through the door or names its
/// reason here. Blind spot, review's: a write through a generic
/// `[keyPath:]` built elsewhere is not seen.
@Suite("App Bar visibility write census (#3517)")
struct AppBarVisibilityWriteCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → (direct writes it holds, why).
    private static let allowed: [String: (Int, String)] = [
        "StarterSetup.swift": (2, "the starter's seed, no pick (#1662)")
    ]

    private static let writes = [
        #"\.appBar\.visibility\s*=(?!=)"#,
        #"\$[\w.]*\.appBar\.visibility\b"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    @Test("every direct layout App Bar Show write is named")
    func writesAreCensused() throws {
        let files = try ["Sources/KiwiDeskCore", "Sources/KiwiDesk"]
            .flatMap {
                try SourceScan.swiftSources(
                    under: Self.root.appendingPathComponent($0)
                )
            }
        #expect(files.count > 100)
        var found: [String: Int] = [:]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let range = NSRange(text.startIndex..., in: text)
            let hits = Self.writes.reduce(0) {
                $0 + $1.numberOfMatches(in: text, range: range)
            }
            guard hits > 0 else { continue }
            found[file.lastPathComponent, default: 0] += hits
        }
        #expect(found == Self.allowed.mapValues(\.0))
    }
}
