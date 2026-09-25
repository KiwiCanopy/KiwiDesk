import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Both bars on the one shelf, through the real drivers (#1517):
/// each takes the segment `ShelfArrangement` gives it on the one
/// strip, the Space Bar drops its front app while an App Bar
/// shares the shelf, and the reservation does not depend on the
/// layout on screen.
@Suite("Shelf drivers (#1517)", .serialized)
@MainActor
struct ShelfDriverTests {
    private static let window = WindowID(1)

    /// A core on the main screen holding one window in a
    /// scrolling space, with both bars on. Nil where the host has
    /// no screen to paint on.
    private func makeShelfCore(appBar: Bool = true) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "ShelfApp",
                    frame: CGRect(
                        x: 100,
                        y: 200,
                        width: 600,
                        height: 400
                    ),
                    isFloating: false
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.window)!
        core.state.workspaces.setMode(space, .scrolling)
        core.state.workspaces.withSpace(space) {
            $0.focused = Self.window
        }
        var settings = core.tiler.settings
        settings.spaceBarStyle.enabled = true
        settings.spaceBarStyle.showFrontApp = true
        settings.scrolling.appBar.enabled = appBar
        settings.kiwishelf.edge = .top
        settings.kiwishelf.thickness = 40
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return core
    }

    @Test(
        "Both bars take disjoint segments of the one strip",
        .enabled(if: NSScreen.main != nil)
    )
    func bothBarsShareTheStrip() throws {
        let core = try #require(makeShelfCore())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let space = try #require(core.spaceBars.shownStrips.first)
        let app = try #require(core.appBars.shownStrips.first)
        let screen = try #require(NSScreen.main)
        let visible = GeometryUtils.axVisibleFrame(of: screen)
        let strip = ShelfGeometry.strip(
            in: visible,
            shelf: core.tiler.settings.kiwishelf
        )
        #expect(strip.contains(space.strip))
        #expect(strip.contains(app.strip))
        #expect(!space.strip.intersects(app.strip))
        // Spaces first by default: one joined plate, the Space
        // section leading, the pair centred on the edge.
        #expect(space.strip.maxX <= app.strip.minX)
        let lead = space.strip.minX - strip.minX
        let trail = strip.maxX - app.strip.maxX
        #expect(abs(lead - trail) <= 1)
        #expect(space.strip.height == strip.height)
        #expect(app.strip.height == strip.height)
    }

    @Test(
        "The front app shows only while no App Bar shares the shelf",
        .enabled(if: NSScreen.main != nil)
    )
    func frontAppYieldsToTheAppBar() throws {
        let shared = try #require(makeShelfCore())
        #expect(!shared.spaceBars.showsTitle(of: Self.window))
        let alone = try #require(makeShelfCore(appBar: false))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(alone.spaceBars.showsTitle(of: Self.window))
        // Alone, the Space Bar spans the whole strip.
        let strip = try #require(alone.spaceBars.shownStrips.first)
        let screen = try #require(NSScreen.main)
        #expect(strip.strip.width == screen.visibleFrame.width)
    }

    @Test(
        "A layout switch moves no window",
        .enabled(if: NSScreen.main != nil)
    )
    func layoutSwitchReflowsNothing() throws {
        let core = try #require(makeShelfCore())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let space = try #require(
            core.state.workspaces.space(of: Self.window)
        )
        func frame(_ mode: LayoutMode) throws -> CGRect {
            core.state.workspaces.setMode(space, mode)
            let input = try #require(
                core.tiler.layoutInput(state: core.state)
            )
            let frames = LayoutEngine.system(for: mode)
                .calculateGeometry(for: input.tiled, in: input.context)
            return try #require(frames[Self.window])
        }
        let monocle = try frame(.monocle)
        #expect(try frame(.bsp) == monocle)
        #expect(try frame(.stack) == monocle)
    }
}
