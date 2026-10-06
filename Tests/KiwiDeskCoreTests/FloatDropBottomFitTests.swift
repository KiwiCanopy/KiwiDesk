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
        KiwiCore.bottomFit(frame, limit: region.maxY, floor: floor)
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

    /// A core showing a bottom Space Bar over the window's space,
    /// one flag float at `frame`; nil without a screen to paint on.
    private func barredCore(
        frame: CGRect,
        edge: AppBarEdge = .bottom
    ) -> KiwiCore? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.tiler.settings.minWindowSize = 200
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: 1,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: true
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.barEdge = edge
        core.tiler.settings.kiwishelf.thickness = 40
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        core.drag.isMousePressed = { false }
        core.drag.cursorLocation = { CGPoint(x: 300, y: 300) }
        return core
    }

    private let id = WindowID(1)

    private func drop(_ core: KiwiCore, _ frame: CGRect) {
        core.handleDragEnd(
            id,
            start: frame.offsetBy(dx: 0, dy: -200),
            frame: frame
        )
    }

    @Test(
        "a drop past a bottom bar is shrunk, never lifted",
        .enabled(if: NSScreen.main != nil)
    )
    func bottomBarShrinksNotLifts() throws {
        let screen = try #require(NSScreen.screens.first).frame
        let frame = CGRect(
            x: screen.minX + 100,
            y: screen.maxY - 400,
            width: 600,
            height: 500
        )
        let core = try #require(barredCore(frame: frame))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let strip = try #require(core.spaceBars.shownStrips.first?.1)
        drop(core, frame)
        let issued = try #require(core.tiler.recentInstantTarget(id))
        #expect(issued.origin == frame.origin)
        #expect(issued.maxY <= strip.minY)
        #expect(issued.maxY >= strip.minY - 2 * core.floatRingInset - 2)
    }

    @Test(
        "past the floor a bottom bar still lifts the window clear",
        .enabled(if: NSScreen.main != nil)
    )
    func floorUnderBarLifts() throws {
        let screen = try #require(NSScreen.screens.first).frame
        let frame = CGRect(
            x: screen.minX + 100,
            y: screen.maxY - 120,
            width: 600,
            height: 500
        )
        let core = try #require(barredCore(frame: frame))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let strip = try #require(core.spaceBars.shownStrips.first?.1)
        drop(core, frame)
        let issued = try #require(core.tiler.recentInstantTarget(id))
        #expect(issued.height == 200)
        #expect(issued.maxY <= strip.minY)
    }

    @Test(
        "a top bar's push past the bottom is trimmed too",
        .enabled(if: NSScreen.main != nil)
    )
    func topBarPushIsTrimmed() throws {
        let screen = try #require(NSScreen.screens.first).frame
        let frame = CGRect(
            x: screen.minX + 100,
            y: screen.minY,
            width: 600,
            height: screen.height - 10
        )
        let core = try #require(barredCore(frame: frame, edge: .top))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let strip = try #require(core.spaceBars.shownStrips.first?.1)
        drop(core, frame)
        let issued = try #require(core.tiler.recentInstantTarget(id))
        #expect(issued.minY >= strip.maxY)
        #expect(issued.maxY <= screen.maxY)
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
