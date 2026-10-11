import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Bars preview gives the corner to the strip the engine
/// measures first — the Space Bar's (#1731, `ShelfGeometry.strips`)
/// — so a split pair is drawn the way the live bars sit.
@MainActor
@Suite("Bars preview corner (#1731)")
struct BarsPreviewCornerTests {
    private func tile(
        space: AppBarEdge,
        app: AppBarEdge,
        spaceBar: Bool = true
    ) -> HomeCardBarsTile {
        var settings = TilingSettings()
        settings.spaceBarStyle.enabled = spaceBar
        settings.monocle.appBar.enabled = true
        settings.spaceBarStyle.edge = space
        settings.appBarStyle.edge = app
        return HomeCardBarsTile(settings: settings)
    }

    @Test("the preview's outer strip is the engine's first edge")
    func cornerFollowsTheEngine() {
        #expect(tile(space: .top, app: .left).rowsRunFullWidth)
        #expect(!tile(space: .left, app: .top).rowsRunFullWidth)
        #expect(
            tile(space: .left, app: .top, spaceBar: false)
                .rowsRunFullWidth
        )
        // The preview asks the engine's list, never its own.
        var settings = TilingSettings()
        settings.spaceBarStyle.edge = .bottom
        settings.appBarStyle.edge = .right
        settings.monocle.appBar.enabled = true
        #expect(
            HomeCardBarsTile(settings: settings).rowsRunFullWidth
                == settings.barEdges(space: true, app: true)
                .first?.edge.isHorizontal
        )
    }

    /// The body draws the branch the predicate names — rows
    /// outer when the rows run the corner.
    @Test("the body takes the predicate's branch")
    func bodyTakesTheBranch() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/HomeCardPlate+Bars.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            source.contains(
                "ifrowsRunFullWidth{rowsOuter}else{columnsOuter}"
            )
        )
        #expect(
            source.contains(
                "varrowsOuter:someView{VStack(spacing:3){rowBars(.top)"
            )
        )
    }
}
