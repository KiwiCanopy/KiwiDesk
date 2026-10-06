import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A float dropped past the bottom of its region keeps its top
/// edge and is shrunk from the bottom (#1427): never moved back up,
/// floored at its minimum height, and only on the drop.
@Suite("A float dropped past the bottom is fitted (#1427)", .serialized)
@MainActor
struct FloatDropBottomFitTests {
    private let region = CGRect(x: 0, y: 40, width: 1440, height: 800)

    private func fit(_ frame: CGRect, floor: CGFloat = 300) -> CGRect {
        KiwiCore.bottomFit(frame, region: region, floor: floor)
    }

    @Test("the bottom is trimmed to the border; the top stays")
    func trimsTheBottom() {
        let frame = CGRect(x: 100, y: 500, width: 600, height: 500)
        let fitted = fit(frame)
        #expect(fitted.origin == frame.origin)
        #expect(fitted.maxY == region.maxY)
        #expect(fitted.width == frame.width)
    }

    @Test("a frame inside the region is untouched")
    func insideIsUntouched() {
        let frame = CGRect(x: 100, y: 300, width: 600, height: 540)
        #expect(fit(frame) == frame)
        // Within the tolerance a sub-point overhang is not fitted.
        let hair = frame.offsetBy(dx: 0, dy: 1)
        #expect(fit(hair) == hair)
    }

    @Test("the floor wins: the rest stays clipped, never moved")
    func floorWins() {
        let frame = CGRect(x: 100, y: 700, width: 600, height: 500)
        let fitted = fit(frame, floor: 300)
        #expect(fitted.origin == frame.origin)
        #expect(fitted.height == 300)
        // A window already smaller than the floor keeps its size,
        // and one above it stops at the floor.
        let small = CGRect(x: 100, y: 800, width: 600, height: 200)
        #expect(fit(small, floor: 300).height == 200)
        #expect(fit(small, floor: 100).height == 100)
    }

    @Test("a frame whose top is past the border is left alone")
    func parkedBelowIsLeft() {
        let frame = CGRect(x: 100, y: 850, width: 600, height: 500)
        #expect(fit(frame) == frame)
    }

    @Test(
        "the drop issues the fitted frame",
        .enabled(if: NSScreen.main != nil)
    )
    func dropIssuesTheFit() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
        core.tiler.visibleBounds = { _ in bounds }
        core.tiler.settings.minWindowSize = 200
        core.state.apply(.displaysChanged([display]))
        let id = WindowID(1)
        let drop = CGRect(x: 100, y: 600, width: 600, height: 500)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: 1,
                    appName: "FloatApp",
                    frame: drop,
                    isFloating: true
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        core.drag.isMousePressed = { false }
        core.drag.cursorLocation = { CGPoint(x: 300, y: 300) }
        core.handleDragEnd(
            id,
            start: drop.offsetBy(dx: 0, dy: -200),
            frame: drop
        )
        let issued = try #require(core.tiler.recentInstantTarget(id))
        #expect(issued.origin == drop.origin)
        #expect(issued.maxY == bounds.maxY)
    }
}
