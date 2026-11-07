import Foundation
import Testing

/// Every sized write the applier sends goes through the edge-band
/// write (#2894): no `FrameApplier` file spells the writer's frame
/// call, which `EdgeBandWrite.write` makes for them. A new write
/// path spelling it directly would skip the lift and bring back
/// the refused shrink near a screen's bottom or right edge.
@Suite("Sized applier writes take the edge-band write (#2894)")
struct EdgeBandWriteSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("no applier file writes a frame past the band")
    func appliersTakeTheBand() throws {
        let tiling = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Tiling"
        )
        let files = try FileManager.default.contentsOfDirectory(
            atPath: tiling.path
        ).filter { $0.hasPrefix("FrameApplier") && $0.hasSuffix(".swift") }
        // The scan must read the applier, or it passed on nothing.
        #expect(files.contains("FrameApplier.swift"))
        var routed = 0
        for file in files {
            let source = try SourceScan.strippedSource(
                at: tiling.appendingPathComponent(file)
            )
            #expect(
                source.occurrences(of: "writer.setFrame(") == 0,
                "\(file) writes a frame past EdgeBandWrite.write"
            )
            #expect(
                source.occurrences(of: "writer.setSize(") == 0,
                "\(file) sizes a window past the band"
            )
            routed += source.occurrences(of: "EdgeBandWrite.write(")
        }
        // apply, applyInstant, the hold's release and writeAway.
        #expect(routed == 4)
    }

    /// A floating resize's write sizes by itself, so it spells the
    /// lift and no frame, and the live writer owes it `frame`,
    /// `setSize` and `sizeSettable`: each defaults inert, and a lost
    /// one compiles (#2981).
    @Test("the size-led write takes the lift, and live wires it")
    func sizeLedTakesTheLift() throws {
        let tiling = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Tiling"
        )
        let led = try SourceScan.strippedSource(
            at: tiling.appendingPathComponent("SizeLedWrite.swift")
        )
        #expect(led.occurrences(of: "EdgeBandWrite.lift(") == 1)
        #expect(led.occurrences(of: "writer.setFrame(") == 0)
        let live = try SourceScan.strippedSource(
            at: tiling.appendingPathComponent(
                "FrameApplier+EnhancedUI.swift"
            )
        )
        #expect(live.occurrences(of: "frame: { element in") == 1)
        #expect(
            live.occurrences(
                of: "setSize: { WindowControl.setSize($0, of: $1) }"
            ) == 1
        )
        #expect(
            live.occurrences(
                of: "sizeSettable: { AXHelper.isSizeSettable($0) }"
            ) == 1
        )
    }

    /// The two waiting-write stores merge a band by one rule, so
    /// a held write and a queued one cannot drift apart.
    @Test("both waiting-write merges take the one rule")
    func mergesTakeTheOneRule() throws {
        let tiling = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Tiling"
        )
        for file in ["FrameApplier+Ledgers.swift", "FrameApplier+Hold.swift"] {
            let source = try SourceScan.strippedSource(
                at: tiling.appendingPathComponent(file)
            )
            #expect(
                source.occurrences(of: "EdgeBandWrite.mergedBand(") == 1,
                "\(file) merges a band past EdgeBandWrite.mergedBand"
            )
        }
    }

    @Test("the engine wires macOS's separate Spaces answer (#2966)")
    func engineWiresSeparateSpaces() throws {
        // A value test cannot red: the unwired default equals the
        // answer on a Mac with the setting off.
        let engine = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/Tiling/TilingEngine.swift"
            )
        )
        let wire =
            "applier.separateSpaces = { "
            + "NSScreen.screensHaveSeparateSpaces }"
        #expect(engine.occurrences(of: wire) == 1)
    }
}
