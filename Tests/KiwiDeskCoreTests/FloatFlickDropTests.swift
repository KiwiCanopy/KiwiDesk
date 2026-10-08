import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A float flicked into a bar strip and released at once is still
/// clamped (#1798): AX throttles moves, so the flick's ONLY move
/// can arrive after the release, and the drag pipeline used to
/// drop it for want of a held button. Driven through the real
/// `.windowMoved` arm with the press record the gesture leaves.
@Suite("Float flick drop (#1798)", .serialized)
@MainActor
struct FloatFlickDropTests {
    private static let window = WindowID(1)

    /// A core showing a top Space Bar over one space in `mode`,
    /// holding one window at `frame`; nil where the host has no
    /// screen to paint on.
    private func makeBarredCore(
        mode: LayoutMode,
        frame: CGRect
    ) -> KiwiCore? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: false
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.window)!
        core.state.workspaces.setMode(space, mode)
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.barEdge = .top
        core.tiler.settings.kiwishelf.thickness = 40
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        core.drag.settleDelay = 0.05
        return core
    }

    /// The window's frame clear of the strip, and the same window
    /// flicked up so its top sits at the screen edge, under it.
    private func frames(
        _ screen: NSScreen
    ) -> (start: CGRect, flicked: CGRect) {
        let start = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY + 200,
            width: 400,
            height: 300
        )
        return (start, start.offsetBy(dx: 0, dy: -200))
    }

    /// Flicks the window with a press at `pressAt`, released now,
    /// then delivers the move the app reports late, and waits for
    /// the pipeline's settle.
    private func flick(
        _ core: KiwiCore,
        to flicked: CGRect,
        pressAt: CGPoint,
        clicks: Int = 1
    ) async {
        core.mouse.seedPress(at: pressAt, clickCount: clicks)
        core.mouse.seedRelease(at: core.wallClock())
        core.handle(.windowMoved(Self.window, flicked))
        await core.drag.settleTask(for: Self.window)?.value
    }

    @Test(
        "A late move after a flick's release is clamped",
        .enabled(if: NSScreen.main != nil)
    )
    func lateFlickIsClamped() async throws {
        let screen = try #require(NSScreen.screens.first)
        let (start, flicked) = frames(screen)
        let core = try #require(
            makeBarredCore(mode: .floating, frame: start)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let painted = try #require(core.spaceBars.shownStrips.first?.1)
        #expect(flicked.minY < painted.maxY)

        await flick(
            core,
            to: flicked,
            pressAt: CGPoint(x: start.midX, y: start.minY + 10)
        )

        let commanded = try #require(
            core.tiler.recentInstantTarget(Self.window),
            "the flick's late move ran no drop (#1798)"
        )
        #expect(commanded.minY >= painted.maxY)
    }

    @Test(
        "A late gesture leaves the Space Bar drop unasked",
        .enabled(if: NSScreen.main != nil)
    )
    func lateGestureSkipsTheBarDrop() async throws {
        let screen = try #require(NSScreen.screens.first)
        let (start, flicked) = frames(screen)
        let core = try #require(
            makeBarredCore(mode: .floating, frame: start)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // The pointer has come to rest on another Space's item
        // since the release; asked, the bar would relocate.
        core.spaceBarDrop.hitTest = { _ in SpaceID(99) }
        let home = core.state.workspaces.space(of: Self.window)

        await flick(
            core,
            to: flicked,
            pressAt: CGPoint(x: start.midX, y: start.minY + 10)
        )

        #expect(core.state.workspaces.space(of: Self.window) == home)
    }

    @Test(
        "A late gesture claims no resize from the #1358 correction",
        .enabled(if: NSScreen.main != nil)
    )
    func lateGestureOwnsNoResize() throws {
        let screen = try #require(NSScreen.screens.first)
        let (start, flicked) = frames(screen)
        let core = try #require(
            makeBarredCore(mode: .floating, frame: start)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.mouse.seedPress(
            at: CGPoint(x: start.midX, y: start.minY + 10)
        )
        core.mouse.seedRelease(at: core.wallClock())
        core.handle(.windowMoved(Self.window, flicked))
        try #require(core.drag.hasGesture(Self.window))

        #expect(!core.isResizeGesture(Self.window))
    }

    @Test(
        "A late move that also resized is no late gesture",
        .enabled(if: NSScreen.main != nil)
    )
    func zoomShapedMoveIsNoLateGesture() throws {
        let screen = try #require(NSScreen.screens.first)
        let (start, _) = frames(screen)
        let core = try #require(
            makeBarredCore(mode: .floating, frame: start)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.mouse.seedPress(
            at: CGPoint(x: start.midX, y: start.minY + 10)
        )
        core.mouse.seedRelease(at: core.wallClock())
        let zoomed = CGRect(
            x: screen.frame.minX,
            y: screen.frame.minY + 100,
            width: start.width + 300,
            height: start.height + 100
        )

        core.handle(.windowMoved(Self.window, zoomed))

        #expect(!core.drag.hasGesture(Self.window))
    }

    @Test(
        "A late move is no gesture without a single press on it",
        .enabled(if: NSScreen.main != nil),
        arguments: [(inside: false, clicks: 1), (inside: true, clicks: 2)]
    )
    func lateMoveNeedsASinglePressOnTheWindow(
        inside: Bool,
        clicks: Int
    ) async throws {
        let screen = try #require(NSScreen.screens.first)
        let (start, flicked) = frames(screen)
        let core = try #require(
            makeBarredCore(mode: .floating, frame: start)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let press =
            inside
            ? CGPoint(x: start.midX, y: start.minY + 10)
            : CGPoint(x: start.maxX + 50, y: start.maxY + 50)

        await flick(core, to: flicked, pressAt: press, clicks: clicks)

        #expect(core.tiler.recentInstantTarget(Self.window) == nil)
    }

    @Test(
        "A tiled window's late move starts no gesture",
        .enabled(if: NSScreen.main != nil)
    )
    func tiledLateMoveIsNoGesture() async throws {
        let screen = try #require(NSScreen.screens.first)
        let (start, flicked) = frames(screen)
        let core = try #require(
            makeBarredCore(mode: .bsp, frame: start)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }

        core.mouse.seedPress(
            at: CGPoint(x: start.midX, y: start.minY + 10)
        )
        core.mouse.seedRelease(at: core.wallClock())
        core.handle(.windowMoved(Self.window, flicked))

        #expect(!core.drag.hasGesture(Self.window))
    }
}
