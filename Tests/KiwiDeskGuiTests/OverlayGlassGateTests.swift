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

    /// Every Core file that mints glass, and the suite that gates
    /// its render — the one copy. Derived from `GlassPlate.make(`
    /// callers, so a new glass host reds until it names its gate.
    private static let minters: [String: String] = [
        "Bar/AppBarOverlay+BoxGlass.swift": "ReduceTransparencySeamTests",
        "Bar/SpaceBarOverlay+BoxGlass.swift": "ReduceTransparencySeamTests",
        "Bar/ShelfOverlay.swift": "ShelfPlateGlassGateTests",
        "Tiling/DragOverlay.swift": "OverlayGlassGateTests",
        "Borders/StickyMarkPlate+Glass.swift": "OverlayGlassGateTests",
    ]

    @Test("every glass host in Core names the gate that covers it")
    func everyGlassHostIsGated() throws {
        var found: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = Array(try SourceScan.strippedSource(at: file))
            guard
                !SourceScan.callSites(in: text, for: "GlassPlate.make")
                    .isEmpty
            else { continue }
            let path = file.standardizedFileURL.path
            let root = Self.core.standardizedFileURL.path + "/"
            found.insert(String(path.dropFirst(root.count)))
        }
        #expect(found.count >= 3, "the scan found \(found)")
        #expect(
            found == Set(Self.minters.keys),
            """
            glass hosts and their gates disagree — a new host owes \
            a gate read where it renders and an entry here: \
            \(found.symmetricDifference(Self.minters.keys))
            """
        )
        // A named gate is a suite that exists, not free text.
        let tests = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Tests/KiwiDeskGuiTests")
        for suite in Set(Self.minters.values) {
            let file = tests.appendingPathComponent("\(suite).swift")
            #expect(
                FileManager.default.fileExists(atPath: file.path),
                "no gate suite \(suite)"
            )
        }
    }
}
