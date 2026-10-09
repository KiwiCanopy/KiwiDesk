import Foundation
import Testing

/// A bar's edge is written through the `ScreenEdged` doors (#1948):
/// a raw `.edge =` or `edgeOverride` write beside them could leave
/// an entry equal to the bar's edge, skip the collapse, or keep a
/// screen's own edge a pick of the bar's edge must clear. Scans
/// both trees; a raw write outside `allowed` reds until it routes
/// through a door or names its reason here.
@Suite("Bar edge write census (#1948)")
struct BarEdgeWriteCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → (raw writes it holds, why).
    private static let allowed: [String: (Int, String)] = [
        "ScreenEdged.swift": (6, "the doors themselves"),
        "ShelfEdge.swift": (1, "`ShelfEdge`'s own field, no bar's"),
        "AppBarStyle+Coding.swift": (2, "its coding key, and the decoder"),
        "SpaceBarStyle+Coding.swift": (2, "its coding key, and the decoder"),
    ]

    private static let patterns = [
        #"\.edge\s*=(?!=)"#,
        #"\bedgeOverride(\[[^\]]*\])?\s*=(?!=)"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    private static func writes(in text: String) -> Int {
        let range = NSRange(text.startIndex..., in: text)
        return patterns.reduce(0) {
            $0 + $1.numberOfMatches(in: text, range: range)
        }
    }

    private func sources() throws -> [URL] {
        let files = try ["Sources/KiwiDeskCore", "Sources/KiwiDesk"]
            .flatMap {
                try SourceScan.swiftSources(
                    under: Self.root.appendingPathComponent($0)
                )
            }
        #expect(files.count > 100)
        return files
    }

    @Test("every raw bar-edge write is a door or a named exemption")
    func rawWritesAreCensused() throws {
        var found: [String: Int] = [:]
        for file in try sources() {
            let count = Self.writes(
                in: try SourceScan.strippedSource(at: file)
            )
            guard count > 0 else { continue }
            found[file.lastPathComponent, default: 0] += count
        }
        #expect(found == Self.allowed.mapValues(\.0))
    }

    /// `barEdges(space:app:)` reads each bar's raw `edge`: a
    /// caller hands it settings already resolved for one screen
    /// (`TilingSettings.onScreen(_:)`), or names why it may read
    /// the bars' own edges.
    private static let foldCallers: [String: (Int, String)] = [
        "TilingSettings+Shelf.swift": (
            2,
            "the declaration, and `shelfEdges(in:on:)` over onScreen"
        ),
        "KiwiCore+ShelfPlan.swift": (
            1,
            "`updateBars()` hands it each display's onScreen copy"
        ),
        "HomeCardPlate+Bars.swift": (
            1,
            "the Home card pictures the bars' own edges until the "
                + "Per screen rows land (#1948 PR 2)"
        ),
    ]

    @Test("every barEdges caller is resolved for a screen or named")
    func foldCallersAreCensused() throws {
        var found: [String: Int] = [:]
        for file in try sources() {
            let text = try SourceScan.strippedSource(at: file)
            let count =
                text.components(separatedBy: "barEdges(")
                .count - 1
            guard count > 0 else { continue }
            found[file.lastPathComponent, default: 0] += count
        }
        #expect(found == Self.foldCallers.mapValues(\.0))
    }
}
