import Foundation
import Testing

/// The pocket's tab takes a bar handle's ink (#3361 ruling 3): its
/// draw asks the one `ShelfHandleSpec.restHex(of:)` for the colour
/// and hands that to the handle's inks, never Automatic spelled out
/// nor the kiwis' own colour beside it. While the accessor answers
/// Automatic no render can tell the two apart, so the call is
/// guarded here. Blind spot, review's: a colour reached through
/// another name.
@Suite("Pocket tab ink seam (#3361)")
struct PocketTabInkSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("the tab's draw inks with the handle's one colour")
    func tabTakesTheHandleColour() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/Bar/PocketHandleView.swift"
            )
        )
        // The tab's part of the draw: from its capsules to the draw's end.
        let start = try #require(
            source.range(of: "ShelfHandleSpec.parts(of: tabRect())")
        )
        let end = try #require(
            source.range(
                of: "context.restoreGState()",
                range: start.upperBound..<source.endIndex
            )
        )
        let tab = String(source[start.lowerBound..<end.upperBound])
        #expect(tab.contains("ShelfHandleSpec.restHex(of: shelf)"))
        #expect(tab.contains("Self.tabCore(hex: ink,"))
        #expect(tab.contains("ShelfHandleSpec.hairlineColor(hex: ink)"))
        #expect(!tab.contains("hex: \"\""))
        #expect(!tab.contains("hex: hex"))
        #expect(!tab.contains("self.hex"))
    }
}
