import Foundation
import Testing

/// BSP's per-split ratios (#3672) have one resolver, one writer and
/// one lifecycle: every ratio door takes its split from
/// `BspLayout.splitOwner` through `bspSplit(of:)`, writes it through
/// `writeCappedBspSplit` alone, and a window's re-key and end reach
/// the store at each door that ends or re-keys a window. A door
/// resolving a split of its own, or writing the shared ratio beside
/// `writeSharedBspRatio`, moves a split the resize did not name; a
/// lifecycle call deleted leaves every behavioural suite green,
/// since none drives that door's whole event.
@Suite("BSP split doors (#3672)")
struct BspSplitDoorSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// Files spelling `needle` outside comments, by name and count.
    private func census(_ needle: String) throws -> [String: Int] {
        var out: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let hits = try SourceScan.strippedSource(at: file)
                .occurrences(of: needle)
            if hits > 0 { out[file.lastPathComponent] = hits }
        }
        return out
    }

    @Test("one resolver, one split writer, one shared writer")
    func doorsHaveOneHome() throws {
        // The resolver's declaration and `splits(of:)`, then the one
        // KiwiCore reader.
        #expect(
            try census("splitOwner(") == [
                "BspLayout+Owner.swift": 2,
                "KiwiCore+ResizeBspSplit.swift": 1,
            ]
        )
        #expect(
            try census("writeBspSplit(") == [
                "KiwiCore+SessionRatioWrite.swift": 1,
                "KiwiCore+ResizeBspSplit.swift": 1,
            ]
        )
        for needle in ["writeSplitRatioH(", "writeSplitRatioV("] {
            #expect(
                try census(needle) == [
                    "KiwiCore+SessionRatioWrite.swift": 1,
                    "KiwiCore+RatioWriters.swift": 1,
                ],
                Comment(rawValue: needle)
            )
        }
    }

    private func body(
        _ path: String,
        after needle: String
    ) throws -> String {
        let text = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(path)
        )
        return try #require(
            SourceScan.declarationBody(after: needle, in: text)
        )
    }

    @Test("a re-key and every window end reach the splits")
    func lifecycleIsWired() throws {
        #expect(
            try body(
                "App/KiwiCore+RekeyEvent.swift",
                after: "func handleWindowRekeyed("
            ).contains("rekeyBspSplits(old, to: new)")
        )
        let gone = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+GoneReason.swift"
            )
        )
        let closed = try #require(
            SourceScan.declarationBody(
                after: "if reason == .closed",
                in: gone
            )
        )
        #expect(closed.contains("forgetBspSplits(of: id)"))
        #expect(
            try body(
                "App/KiwiCore+PreFold.swift",
                after: "func prepareAppExit("
            ).contains("forgetBspSplits(of: window.id)")
        )
        #expect(
            try body(
                "App/KiwiCore+AwayWindows.swift",
                after: "func retireAwayDebts(of id: WindowID)"
            ).contains("forgetBspSplits(of: id)")
        )
        #expect(
            try body(
                "Commands/KiwiCore+SpaceCommands.swift",
                after: "func settleFiling("
            ).contains(
                "if let from, from != target { forgetBspSplits(of: window) }"
            )
        )
        #expect(
            try body(
                "Tiling/KiwiCore+DragRelocate.swift",
                after: "func commitCrossDisplayDrop("
            ).contains("forgetBspSplits(of: id)")
        )
        // The undo rebase forgets with the live store, or an undo
        // after the owner closes reads the Space as changed (#3601).
        #expect(
            try body(
                "Models/SpaceArrangement+Rebase.swift",
                after: "func removing("
            ).contains("sizes.ratios.bspSplits?.forget(window)")
        )
    }
}
