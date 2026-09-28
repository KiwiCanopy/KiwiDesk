import Foundation
import Testing

/// Glass is the starter's styling for the connected screens
/// (#1739): derived from `StarterSetup.settings(sizes:)`, never
/// from `TilingSettings()`, and every caller reaches the bundled
/// looks through `KiwiCore.bundledLooks`, which sizes them from
/// the one `starterSizes()` the starter itself is built from.
/// Shape pins, since today no starter tuning moves a look key and
/// a value clause could not tell the two derivations apart.
@Suite("Look catalog seam (#1739)")
struct LookCatalogSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func sources() throws -> [URL] {
        let files = try ["Sources/KiwiDeskCore", "Sources/KiwiDesk"]
            .flatMap {
                try SourceScan.swiftSources(
                    under: Self.root.appendingPathComponent($0)
                )
            }
        #expect(!files.isEmpty)
        return files
    }

    private func count(_ needle: String) throws -> [String: Int] {
        var hits: [String: Int] = [:]
        for file in try sources() {
            let text = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
            let n = text.components(separatedBy: needle).count - 1
            if n > 0 { hits[file.lastPathComponent] = n }
        }
        return hits
    }

    /// The unqualified count catches a call inside the catalog
    /// and one a line break split from its `LookCatalog.`.
    @Test("the bundled looks have one door")
    func oneDoor() throws {
        #expect(
            try count("LookCatalog.bundled(")
                == ["KiwiCore+Looks.swift": 1]
        )
        #expect(
            try count("bundled(sizes:")
                == ["LookCatalog.swift": 1, "KiwiCore+Looks.swift": 1]
        )
        #expect(
            try count("defaultLook(") == ["LookCatalog.swift": 2]
        )
    }

    @Test("the door sizes Glass as the starter is sized")
    func doorTakesStarterSizes() throws {
        let file = try #require(
            try sources().first {
                $0.lastPathComponent == "KiwiCore+Looks.swift"
            }
        )
        let squashed = try SourceScan.strippedSource(at: file)
            .filter { !$0.isWhitespace }
        #expect(
            squashed.contains(
                "LookCatalog.bundled(sizes:starterSizes())"
            )
        )
    }

    @Test("Glass is derived from the starter's settings")
    func glassReadsTheStarter() throws {
        let file = try #require(
            try sources().first {
                $0.lastPathComponent == "LookCatalog.swift"
            }
        )
        let squashed = try SourceScan.strippedSource(at: file)
            .filter { !$0.isWhitespace }
        #expect(
            squashed.contains(
                "LookKeys.extract(from:StarterSetup.settings(sizes:sizes))"
            )
        )
        #expect(!squashed.contains("TilingSettings()"))
    }
}
