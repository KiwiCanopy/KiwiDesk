import Foundation
import Testing

/// Where Reduce transparency is READ, and where it re-renders
/// (#1374). The behaviour is `ReduceTransparencyTests`'; this
/// holds the wiring a behavioural test cannot see: that each
/// bar's render takes the gate, that the flip re-draws both bars,
/// and that the OS flag has one home per tree.
@Suite("Reduce transparency seam (#1374)")
struct ReduceTransparencySeamTests {
    private static var root: URL {
        SourceScan.repoRoot(from: #filePath)
    }
    private static var core: URL {
        root.appendingPathComponent("Sources/KiwiDeskCore")
    }
    private static var gui: URL {
        root.appendingPathComponent("Sources/KiwiDesk")
    }

    /// Each overlay's `render` resolves the stored style through
    /// the gate exactly once — a second read beside it, or none,
    /// is a bar drawing what the other does not.
    @Test("each bar's render takes the gate once")
    func rendersTakeTheGate() throws {
        for (file, declaration) in [
            ("Bar/AppBarOverlay.swift", "func render(followingFocus"),
            (
                "Bar/SpaceBarOverlay+Render.swift",
                "func render(followingActive"
            ),
        ] {
            let source = try SourceScan.strippedSource(
                at: Self.core.appendingPathComponent(file)
            )
            let body = try #require(
                SourceScan.declarationBody(
                    after: declaration,
                    in: source
                ),
                Comment(rawValue: "\(file): render did not parse")
            )
            #expect(
                SourceScan.callSites(
                    in: Array(body),
                    for: "LiquidGlassGate.rendered"
                ).count == 1,
                Comment(
                    rawValue:
                        "\(file): render resolves the style through "
                        + "LiquidGlassGate.rendered other than once"
                )
            )
        }
    }

    /// The flip re-draws BOTH bars from the bootstrap wiring; a
    /// handler that forgot one leaves that bar on stale glass
    /// until its next unrelated retile.
    @Test("the flip re-renders both bars")
    func flipRerendersBothBars() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+Bootstrap.swift"
            )
        )
        let handler = try #require(
            SourceScan.declarationBody(
                after: "LiquidGlassGate.observe",
                in: source
            ),
            "bootstrap no longer observes the gate"
        )
        for update in ["updateAppBar()", "updateSpaceBar()"] {
            #expect(
                handler.contains(update),
                Comment(rawValue: "the flip handler skips \(update)")
            )
        }
    }

    /// One reader of the OS flag per tree: `LiquidGlassGate` in
    /// Core, the `GlassChrome` modifier in the GUI. A second
    /// reader is a second gate free to disagree with the first.
    @Test("the OS flag has one home per tree")
    func oneReaderPerTree() throws {
        let coreReaders = try Self.files(
            under: Self.core,
            spelling: "accessibilityDisplayShouldReduceTransparency"
        )
        #expect(coreReaders == ["LiquidGlassGate.swift"])
        let guiReaders = try Self.files(
            under: Self.gui,
            spelling: "accessibilityReduceTransparency"
        )
        #expect(guiReaders == ["GlassChrome.swift"])
        // Neither tree reaches across for the other's spelling.
        #expect(
            try Self.files(
                under: Self.gui,
                spelling: "accessibilityDisplayShouldReduceTransparency"
            ).isEmpty
        )
        #expect(
            try Self.files(
                under: Self.core,
                spelling: "accessibilityReduceTransparency"
            ).isEmpty
        )
    }

    /// The GUI reader gates the glass branch and nothing else:
    /// the modifier hands `glassGround` the conjunction, so the
    /// clip and the `.regularMaterial` fallback are untouched.
    @Test("GlassChrome gates the branch on the environment")
    func glassChromeGatesTheBranch() throws {
        let source = try SourceScan.strippedSource(
            at: Self.gui.appendingPathComponent(
                "Settings/Components/Common/GlassChrome.swift"
            )
        )
        let modifier = try #require(
            SourceScan.declarationBody(
                after: "struct GlassChrome",
                in: source
            ),
            "the GlassChrome modifier is gone"
        )
        let squashed = modifier.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(
            squashed.contains(
                "@Environment(\\.accessibilityReduceTransparency)"
            ),
            "GlassChrome no longer reads the environment"
        )
        #expect(
            squashed.contains("enabled:enabled&&!reduceTransparency"),
            "GlassChrome no longer stands the glass branch down"
        )
    }

    private static func files(
        under root: URL,
        spelling: String
    ) throws -> [String] {
        try SourceScan.swiftSources(under: root)
            .filter { file in
                try SourceScan.strippedSource(at: file).contains(spelling)
            }
            .map { $0.lastPathComponent }
            .sorted()
    }
}
