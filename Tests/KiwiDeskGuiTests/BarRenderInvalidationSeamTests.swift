import Foundation
import Testing

/// A bar overlay skips a show whose input repeats (#1901), so a
/// draw-time read outside that input — Reduce transparency through
/// `LiquidGlassGate`, the installed fonts through `BarFont` — must
/// invalidate before it refreshes, or the bars keep drawing the old
/// look. Each observer body calls the one door ahead of its
/// `updateBars()`, and the door reaches all three managers. A new
/// draw-time read joins `observers` with the body that refreshes it.
@Suite("Bar render invalidation seam (#1901)")
struct BarRenderInvalidationSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → the observer body that refreshes a draw-time read.
    private static let observers = [
        "KiwiCore+ReduceTransparency.swift":
            "func reduceTransparencyDidChange()",
        "KiwiCore+FontSet.swift": "func fontSetDidChange()",
    ]

    private static let door = "invalidateBarRenders()"

    private func source(_ name: String) throws -> String {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore"
            )
        )
        let file = try #require(
            files.first { $0.lastPathComponent == name }
        )
        return try SourceScan.strippedSource(at: file)
    }

    @Test("each draw-time observer invalidates before it refreshes")
    func observersInvalidateFirst() throws {
        for (name, declaration) in Self.observers {
            let body = try #require(
                SourceScan.declarationBody(
                    after: declaration,
                    in: try source(name)
                ),
                "\(name) lost \(declaration)"
            )
            let invalidate = try #require(
                body.range(of: Self.door),
                "\(declaration) never invalidates"
            )
            let refresh = try #require(
                body.range(of: "updateBars()"),
                "\(declaration) never refreshes"
            )
            #expect(
                invalidate.lowerBound < refresh.lowerBound,
                "\(declaration) refreshes before it invalidates"
            )
        }
    }

    @Test("the door reaches both bars and the shelves")
    func doorReachesEveryManager() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "func \(Self.door)",
                in: try source("KiwiCore+Shelf.swift")
            )
        )
        for manager in ["appBars", "spaceBars", "shelves"] {
            #expect(
                body.contains("\(manager).invalidateRenders()"),
                "the door skips \(manager)"
            )
        }
    }
}
