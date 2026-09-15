import Foundation
import Testing

/// The weight heal folds on the render's cap (#944), which since
/// #1355 reads the learned bounds — so the heal takes the
/// render's own input through `layoutInput` rather than a
/// context built beside it, reads the floors through the one
/// `learnedFloor`, and the pass-scoped probe flag has ONE writer,
/// `withForcedPass`, which `KiwiCore.retile` wraps the heal in
/// so a forced render and its heal fold alike. Routing scans
/// (`SizeBoundGateNeedleTests`' polarity); the behavioral half
/// is `TrackFloorHealTests`.
@Suite("Track cap plumbing needle (#1355)")
struct TrackCapPlumbingNeedleTests {
    @Test("The weight heal reads the render's own layout input")
    func healRoutesThroughLayoutInput() throws {
        let source = try SourceScan.functionBody(
            of: "healSessionWeights",
            in: "KiwiCore+WeightHeal.swift",
            under: "Commands"
        )
        #expect(source.contains("tiler.layoutInput("))
        #expect(!source.contains("settings.context("))
        #expect(!source.contains("probesBeyondBounds ="))
    }

    @Test("The floor heal reads the one floor reading")
    func floorHealReadsLearnedFloor() throws {
        let source = try SourceScan.functionBody(
            of: "healTrackFloors",
            in: "KiwiCore+FloorHeal.swift",
            under: "Commands"
        )
        #expect(source.contains("learnedFloor("))
        #expect(!source.contains("minWidth"))
    }

    @Test("The pass flag has one writer and the heal runs inside it")
    func forcedPassHasOneWriter() throws {
        let door = try SourceScan.functionBody(
            of: "withForcedPass",
            in: "TilingEngine+SizeBounds.swift",
            under: "Tiling"
        )
        #expect(door.contains("probeBeyondBoundsPass = force"))
        let writes = try coreWideCount(
            of: "probeBeyondBoundsPass = "
        )
        // The door's set and its restore, nowhere else.
        #expect(writes == 2)
        let retile = try SourceScan.functionBody(
            of: "retile",
            in: "KiwiCore+Retile.swift",
            under: "App"
        )
        // Inside the door's own block, not merely somewhere in
        // the body — one line above the brace is the regression.
        let characters = Array(retile)
        let opener = Array("withForcedPass(pass.probes) {")
        let start = try #require(
            (0...(characters.count - opener.count)).first {
                Array(characters[$0..<($0 + opener.count)])
                    == opener
            }
        )
        var cursor = start + opener.count - 1
        let block = try #require(
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "{",
                close: "}"
            )
        )
        #expect(block.contains("healTrackSessionWeights()"))
    }

    private func coreWideCount(
        of needle: String,
        _ path: StaticString = #filePath
    ) throws -> Int {
        let root = SourceScan.repoRoot(from: "\(path)")
            .appendingPathComponent("Sources/KiwiDeskCore")
        let files = try #require(
            FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil
            )
        )
        var count = 0
        for case let url as URL in files
        where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            // Assignments only — the property's own declaration
            // is not a write.
            count +=
                text.split(separator: "\n").filter {
                    $0.contains(needle)
                        && !$0.contains("var probeBeyondBoundsPass")
                }.count
        }
        return count
    }
}
