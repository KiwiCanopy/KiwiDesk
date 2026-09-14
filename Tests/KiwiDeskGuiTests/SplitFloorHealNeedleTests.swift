import Foundation
import Testing

/// The split floor heal's routing (#934/#1430): it runs inside
/// `KiwiCore.retile`'s one forced-pass scope beside the track
/// heal, reads the render's own `layoutInput` over the LOCAL
/// members, writes only through the capped writers, and the
/// inward overflow is the one post-pass on the frames the retile
/// ISSUES, never on the slots every reader keeps. Routing scans
/// (`TrackCapPlumbingNeedleTests`' polarity); the behavioral half
/// is `SplitFloorHealWiringTests` and `SplitFloorCueTests`.
@Suite("Split floor heal needle (#934)")
struct SplitFloorHealNeedleTests {
    @Test("The heal runs inside retile's forced-pass scope")
    func healRunsInsideTheForcedPass() throws {
        let retile = try SourceScan.functionBody(
            of: "retile",
            in: "KiwiCore+Retile.swift",
            under: "App"
        )
        let characters = Array(retile)
        let opener = Array("withForcedPass(force) {")
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
        #expect(block.contains("healSplitFloors()"))
    }

    @Test("The heal reads the render's input over the local members")
    func healReadsLayoutInputOverLocalMembers() throws {
        let source = try SourceScan.functionBody(
            of: "healSpaceSplitFloors",
            in: "KiwiCore+SplitFloorHeal.swift",
            under: "Commands"
        )
        #expect(source.contains("tiler.layoutInput("))
        #expect(!source.contains("settings.context("))
        #expect(source.contains("localTiledMembers("))
        #expect(!source.contains("effectiveTiledMembers("))
        #expect(source.contains("probesBeyondBounds"))
    }

    @Test("The heal writes only through the capped writers")
    func healWritesThroughTheCappedWriters() throws {
        let source = try healSource()
        #expect(source.contains("writeCappedBspRatio("))
        #expect(source.contains("writeCappedMasterRatio("))
        #expect(!source.contains("writeSplitRatioH("))
        #expect(!source.contains("writeSplitRatioV("))
        #expect(!source.contains("writeMasterRatio("))
        // No focus, so the writer clamps and cues nothing.
        #expect(!source.contains("focused: space.focused"))
    }

    @Test("The retile issues the placed frames; readers keep the slots")
    func retileIssuesPlacedFrames() throws {
        let retile = try SourceScan.functionBody(
            of: "retile",
            in: "TilingEngine.swift",
            under: "Tiling"
        )
        #expect(retile.contains("placedFrames(state: state)"))
        #expect(!retile.contains("calculatedFrames(state: state)"))
        let slots = try SourceScan.functionBody(
            of: "calculatedFrames",
            in: "TilingEngine+Layout.swift",
            under: "Tiling"
        )
        #expect(slots.contains("placed: false"))
        let issued = try SourceScan.functionBody(
            of: "placedFrames",
            in: "TilingEngine+PlacedFrames.swift",
            under: "Tiling"
        )
        #expect(issued.contains("placed: true"))
        let placed = try SourceScan.functionBody(
            of: "placed",
            in: "SplitOverflow.swift",
            under: "Layouts"
        )
        #expect(placed.contains("case .bsp, .stack:"))
        #expect(placed.contains("inward("))
        // One mechanism per store (owner ruling 2026-09-14): the
        // math has one consumer, the post-pass one caller, and
        // the layout dispatcher stays pure.
        #expect(try coreWideCount(of: "SplitDomain.healedRatio(") == 1)
        #expect(try coreWideCount(of: "SplitOverflow.placed(") == 1)
        let calculate = try SourceScan.functionBody(
            of: "calculate",
            in: "LayoutEngine.swift",
            under: "Layouts"
        )
        #expect(!calculate.contains("SplitOverflow"))
    }

    private func healSource(
        _ path: StaticString = #filePath
    ) throws -> String {
        let url = SourceScan.repoRoot(from: "\(path)")
            .appendingPathComponent("Sources/KiwiDeskCore/Commands")
            .appendingPathComponent("KiwiCore+SplitFloorHeal.swift")
        return try SourceScan.strippedSource(at: url)
    }

    private func coreWideCount(
        of needle: String,
        _ path: StaticString = #filePath
    ) throws -> Int {
        let root = SourceScan.repoRoot(from: "\(path)")
            .appendingPathComponent("Sources/KiwiDeskCore")
        var count = 0
        for url in try SourceScan.swiftSources(under: root) {
            let text = try SourceScan.strippedSource(at: url)
            count += text.components(separatedBy: needle).count - 1
        }
        return count
    }
}
