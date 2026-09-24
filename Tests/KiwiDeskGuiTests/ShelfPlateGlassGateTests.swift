import Foundation
import Testing

/// Split from `ReduceTransparencySeamTests` at the file ceiling:
/// the shelf's plate is gated where its glass is decided (#1374,
/// #1517).
@Suite("Reduce transparency seam: shelf plate")
struct ShelfPlateGlassGateTests {
    private static var root: URL {
        SourceScan.repoRoot(from: #filePath)
    }

    /// The shelf's own plate (#1517) is a render too: its glass is
    /// decided in `ShelfManager.relayout`, which hands the overlay
    /// the gated shelf and reads the stored one nowhere beside it.
    @Test("the shelf plate renders through the gate, once")
    func shelfPlateTakesTheGate() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/Bar/ShelfManager.swift"
            )
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func relayout(",
                in: source
            )
        )
        #expect(
            SourceScan.callSites(
                in: Array(body),
                for: "LiquidGlassGate.rendered"
            ).count == 1
        )
        let stored = try #require(
            SourceScan.callArguments(
                of: "LiquidGlassGate.rendered(",
                in: body
            )?.trimmingCharacters(in: .whitespaces)
        )
        #expect(stored == "shelf.shelf")
        #expect(body.occurrences(of: stored) == 1)
    }
}
