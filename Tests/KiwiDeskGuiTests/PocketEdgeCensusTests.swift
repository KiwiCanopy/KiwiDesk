import Foundation
import Testing

/// The pocket's edge is written through `KiwiShelf.pocketEdges`'
/// `ScreenEdged` doors and read resolved for a screen (#3376), as a
/// bar's is (`BarEdgeWriteCensusTests`, #1948). Writes: a raw
/// `pocketEdge =` or `pocketEdgeOverride =`, or a key path to either
/// beside the doors, could leave an entry equal to the pocket's
/// edge, skip the collapse, or keep a screen's own edge a pick of
/// the pocket's edge must clear. Reads: Core's
/// `tiler.settings.kiwishelf.pocketEdge` answers for no screen,
/// where a display's reader takes `KiwiCore.shelf(on:)` or
/// `settings(on:)`. Both trees are scanned for writes, Core for
/// reads; a hit outside its map reds until it routes through a door
/// or names its reason here. Blind spots, review's: a SwiftUI
/// binding's dynamic member (`shelf.pocketEdge` on a
/// `Binding<KiwiShelf>`) reads like a read, and a read through a
/// local copy of the unresolved shelf is not seen.
@Suite("Pocket edge census (#3376)")
struct PocketEdgeCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → (raw writes it holds, why).
    private static let writers: [String: (Int, String)] = [
        "KiwiShelf.swift": (1, "the stored property's declaration"),
        "KiwiShelf+Coding.swift": (2, "its decoder"),
        "KiwiShelf+PocketEdges.swift": (
            2, "`pocketEdges`' setter, the doors' one way in"
        ),
        "SettingsRevertRegister+Rules.swift": (
            2, "the ↺ copies the baseline's edge pair (#792)"
        ),
    ]

    /// File → (unresolved Core reads it holds, why).
    private static let readers: [String: (Int, String)] = [
        "KiwiCore+PocketPlate.swift": (
            1, "the edge of a pocket view no screen holds, a fallback"
        )
    ]

    private static func regexes(_ patterns: [String]) -> [NSRegularExpression]
    {
        patterns.map { try! NSRegularExpression(pattern: $0) }
    }

    private static let writes = regexes([
        // A `let` names a local and a `case` an enum's raw value,
        // neither the stored field; the cost is a `let` or `case`
        // of a store named so, which review sees.
        #"(?<!let )(?<!case )\bpocketEdge(Override)?(\[[^\]]*\])?\s*=(?!=)"#,
        // A key path handed to `map` reads; any other may write.
        #"(?<!map\()\\[\w.]*\.pocketEdge(Override)?\b"#,
    ])

    private static let reads = regexes([
        #"\btiler\.settings\.kiwishelf\.pocketEdge\b"#
    ])

    private func census(
        in dirs: [String],
        _ regexes: [NSRegularExpression]
    ) throws -> [String: Int] {
        let files = try dirs.flatMap {
            try SourceScan.swiftSources(
                under: Self.root.appendingPathComponent($0)
            )
        }
        #expect(files.count > 100)
        var found: [String: Int] = [:]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let range = NSRange(text.startIndex..., in: text)
            let count = regexes.reduce(0) {
                $0 + $1.numberOfMatches(in: text, range: range)
            }
            guard count > 0 else { continue }
            found[file.lastPathComponent, default: 0] += count
        }
        return found
    }

    @Test("every raw pocket-edge write is a door or a named exemption")
    func rawWritesAreCensused() throws {
        let found = try census(
            in: ["Sources/KiwiDeskCore", "Sources/KiwiDesk"],
            Self.writes
        )
        #expect(found == Self.writers.mapValues(\.0))
    }

    @Test("every unresolved Core read of the pocket's edge is named")
    func readsAreCensused() throws {
        let found = try census(in: ["Sources/KiwiDeskCore"], Self.reads)
        #expect(found == Self.readers.mapValues(\.0))
    }
}
