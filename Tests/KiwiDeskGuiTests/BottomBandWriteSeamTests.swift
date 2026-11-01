import Foundation
import Testing

/// Every sized write the applier sends goes through the bottom-band
/// write (#2894): no `FrameApplier` file spells the writer's frame
/// call, which `BottomBandWrite.write` makes for them. A new write
/// path spelling it directly would skip the lift and bring back
/// the refused shrink near a screen's bottom.
@Suite("Sized applier writes take the bottom-band write (#2894)")
struct BottomBandWriteSeamTests {
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
                "\(file) writes a frame past BottomBandWrite.write"
            )
            routed += source.occurrences(of: "BottomBandWrite.write(")
        }
        // apply, applyInstant and the hold's release.
        #expect(routed == 3)
    }

    /// Unwired, the tracked height reads every bottom-edge write
    /// (#2894): nothing reds but the AX count, so the wiring is
    /// pinned here.
    @Test("the core wires the tracked height once")
    func trackedHeightIsWired() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
            )
        )
        #expect(
            source.occurrences(of: "tiler.applier.trackedHeight =") == 1
        )
        // The window's echo-fed frame, never a frame we asked for.
        #expect(
            source.occurrences(of: "state.windows[id]?.frame.height") == 1
        )
    }
}
