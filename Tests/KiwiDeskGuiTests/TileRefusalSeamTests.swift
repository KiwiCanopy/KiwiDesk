import Foundation
import Testing

/// Detection's float verdict has one reader per purpose (#1810):
/// the float verbs and the bar menu's Float/Tile row read it
/// through `KiwiCore.tileRefusal(of:)`, never beside it, and the
/// verdict is composed in `EventLoop.autoFloatVerdict` alone. A
/// second reader is where the row and the pill would come apart,
/// and every behaviour suite hands the verdict in, so none sees a
/// reader going round the door. Scanned here because `SourceScan`
/// lives in the GUI test target (AGENTS.md §1).
@Suite("Tile refusal seam (#1810)")
struct TileRefusalSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Stripped Core source per file path under `KiwiDeskCore/`.
    private static func coreSources() throws -> [String: String] {
        let base = root.appendingPathComponent("Sources/KiwiDeskCore")
        var found: [String: String] = [:]
        for file in try SourceScan.swiftSources(under: base) {
            let key = String(
                file.path.dropFirst(base.path.count + 1)
            )
            found[key] = try SourceScan.strippedSource(at: file)
        }
        return found
    }

    /// Per file, how often `needle` appears, zero-count files left
    /// out.
    private static func census(
        _ needle: String,
        in sources: [String: String]
    ) -> [String: Int] {
        sources.compactMapValues {
            let count = $0.occurrences(of: needle)
            return count > 0 ? count : nil
        }
    }

    @Test("the verdict is read only by tileRefusal")
    func verdictHasOneReader() throws {
        let sources = try Self.coreSources()
        #expect(sources.count > 100, "the scan read too little")
        #expect(
            // Call-shaped: the declaration spells `(for id:`.
            Self.census("detectionVerdict(for:", in: sources) == [
                "Commands/KiwiCore+FloatCommands.swift": 1
            ]
        )
        let door = try SourceScan.functionBody(
            of: "tileRefusal",
            in: "KiwiCore+FloatCommands.swift",
            under: "Commands"
        )
        #expect(door.contains("detectionVerdict(for:"))
    }

    /// The verbs and the row, and nobody else: a new reader
    /// states itself here.
    @Test("tileRefusal's callers are the verbs and the menu row")
    func doorCallers() throws {
        let sources = try Self.coreSources()
        let calls = Self.census("tileRefusal(of:", in: sources)
        #expect(
            calls == [
                // The verb's refusal (the declaration spells
                // `(of id:`).
                "Commands/KiwiCore+FloatCommands.swift": 1,
                // The single row and each submenu row.
                "App/KiwiCore+BarWindowMenus.swift": 2,
            ]
        )
    }

    @Test("the verdict is composed in autoFloatVerdict alone")
    func oneComposition() throws {
        let sources = try Self.coreSources()
        #expect(
            Self.census("FloatDetection.autoFloatReason(", in: sources)
                == ["Events/EventLoop+WindowPolicy.swift": 1]
        )
        let composition = try SourceScan.functionBody(
            of: "autoFloatVerdict",
            in: "EventLoop+WindowPolicy.swift",
            under: "Events"
        )
        #expect(composition.contains("FloatDetection.autoFloatReason("))
        #expect(composition.contains("forceFloatReason("))
        // Both producers take the one composition.
        let tracking = sources["Events/EventLoop+Tracking.swift"] ?? ""
        #expect(tracking.occurrences(of: "autoFloatVerdict(") == 2)
    }
}
