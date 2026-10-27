import Foundation
import Testing

/// The drag markers', the sticky mark's and KiwiVision's plate's
/// glass is decided where each is rendered, through the one gate
/// (#1374, #1620, #1621, #2103) —
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
            file: "Tiling/DragMarkerView.swift",
            function: "func redrawPreview(",
            stored: "glass: input.storedGlass"
        ),
        (
            file: "App/KiwiCore+StickyMarks.swift",
            function: "func stickyMarkSpecs(",
            stored: "glass: tiler.settings.stickyStyle.liquidGlass"
        ),
        (
            // The overflow mark wears the shelf's look (#2235).
            file: "App/KiwiCore+OverflowMarks.swift",
            function: "func overflowMarkSpecs(",
            stored: "tiler.settings.kiwishelf"
        ),
        (
            // A hidden bar's mark wears its bar's glass (#2567).
            file: "App/KiwiCore+ShelfReveal.swift",
            function: "func fileEdge(",
            stored: "settings.kiwishelf"
        ),
        (
            file: "App/KiwiCore+Vision.swift",
            // The door over a look (#2103 PR 7); the live
            // `kiwiVisionDrawsBlur` hands it `visionLook`.
            function: "func kiwiVisionDrawsBlur(for look: VisionLook)",
            stored: "blur: look.blur"
        ),
        (
            // The brief pocket's plate and pocket (#2680).
            file: "App/KiwiCore+BriefPocket.swift",
            function: "func briefPocketPlateGlass(",
            stored: "glass: tiler.settings.shortcutPanelLiquidGlass"
        ),
        (
            file: "App/KiwiCore+BriefPocket.swift",
            function: "func briefPocketShelf(",
            stored: "tiler.settings.kiwishelf"
        ),
        (
            file: "Commands/KiwiCore+SpaceSlide.swift",
            function: "func prepareSpaceSlide(",
            stored: "glass: tiler.settings.shortcutPanelLiquidGlass"
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
            let leaf = try #require(
                stored.split(separator: " ", maxSplits: 1).last
                    .map(String.init)
            )
            #expect(
                body.occurrences(of: leaf) == 1,
                "\(render.file) reads \(leaf) beside the gate"
            )
        }
    }

    /// Every Core file that mints glass, and the suite that gates
    /// its render — the one copy. Derived from `GlassPlate.make(`
    /// and `GlassBox.make(` callers, so a new glass host reds until
    /// it names its gate.
    private static let minters: [String: String] = [
        // The box mint behind the three callers below (#2150).
        "Bar/GlassBox.swift": "ReduceTransparencySeamTests",
        "Bar/SpaceBarOverlay+BoxGlass.swift": "ReduceTransparencySeamTests",
        "Bar/AppBarOverlay+BoxGlass.swift": "ReduceTransparencySeamTests",
        "Bar/ShelfOverlay+Views.swift": "ShelfPlateGlassGateTests",
        "Tiling/DragMarkerView.swift": "OverlayGlassGateTests",
        "Borders/StickyMarkPlate+Glass.swift": "OverlayGlassGateTests",
        "Borders/OverflowMarkView.swift": "OverlayGlassGateTests",
        "Animation/SpaceSlideOverlay+Plates.swift": "OverlayGlassGateTests",
        "Animation/BriefPocketViews.swift": "OverlayGlassGateTests",
        "Bar/BarPeekPanel.swift": "BarPeekSeamTests",
        "Vision/VisionPlate.swift": "OverlayGlassGateTests",
        "Bar/ShelfHandleView.swift": "OverlayGlassGateTests",
    ]

    @Test("every glass host in Core names the gate that covers it")
    func everyGlassHostIsGated() throws {
        var found: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = Array(try SourceScan.strippedSource(at: file))
            guard
                ["GlassPlate.make", "GlassBox.make"].contains(where: {
                    !SourceScan.callSites(in: text, for: $0).isEmpty
                })
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
