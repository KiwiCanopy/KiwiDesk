import Foundation
import Testing

/// The drag markers' and the sticky mark's glass is decided where
/// each is rendered, through the one gate (#1374, #1620, #1621) —
/// the shelf plate's rule (`ShelfPlateGlassGateTests`) for two
/// surfaces that host glass without `GlassHosting`, which
/// `ReduceTransparencySeamTests`' host scan cannot see.
@Suite("Reduce transparency seam: drag markers and sticky mark")
struct OverlayGlassGateTests {
    private static var core: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Each render: its file, the function that decides the glass,
    /// and the stored leaf it hands the gate.
    private static let renders = [
        (
            file: "Tiling/KiwiCore+DragMove.swift",
            function: "func handleDragMove(",
            stored: "glass: settings.dragLiquidGlass"
        ),
        (
            file: "App/KiwiCore+StickyMarks.swift",
            function: "func updateStickyMarks(",
            stored: "glass: tiler.settings.stickyStyle.liquidGlass"
        ),
    ]

    /// Exactly one gate read, handed the stored leaf, which the
    /// body names nowhere beside it — a second read of the leaf
    /// is a way for the flat look to skip the stand-down.
    @Test("each overlay renders its glass through the gate, once")
    func overlaysTakeTheGate() throws {
        for render in Self.renders {
            let source = try SourceScan.strippedSource(
                at: Self.core.appendingPathComponent(render.file)
            )
            let body = try #require(
                SourceScan.declarationBody(
                    after: render.function,
                    in: source
                ),
                "\(render.function) is gone"
            )
            #expect(
                SourceScan.callSites(
                    in: Array(body),
                    for: "LiquidGlassGate.rendered"
                ).count == 1,
                "\(render.file)"
            )
            let stored = try #require(
                SourceScan.callArguments(
                    of: "LiquidGlassGate.rendered(",
                    in: body
                )?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            #expect(stored == render.stored, "\(render.file)")
            let leaf = String(stored.dropFirst("glass: ".count))
            #expect(
                body.occurrences(of: leaf) == 1,
                "\(render.file) reads \(leaf) beside the gate"
            )
        }
    }
}
