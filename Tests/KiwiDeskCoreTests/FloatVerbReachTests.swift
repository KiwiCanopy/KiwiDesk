import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `move_floating` and the grow side of `resize` reach as far as a
/// hand drag does (#3163, owner ruling 2026-11-10): the screen's
/// visible edge, or a bar on the top edge. A bar on the bottom or a
/// side stops neither.
@Suite("Float verbs reach the screen edge (#3163)", .serialized)
@MainActor
struct FloatVerbReachTests {
    private static let window = WindowID(1)

    /// A core showing a Space Bar on `edge` over one floating space,
    /// one focused float at `frame`. Writes are instant, so each one
    /// is the applier's instant target. Nil where no screen paints.
    private func makeBarredCore(
        edge: AppBarEdge,
        frame: CGRect
    ) -> KiwiCore? {
        guard let screen = NSScreen.screens.first,
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
                    pid: 900_001,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: true
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.window)!
        core.state.workspaces.setMode(space, .floating)
        core.state.apply(.windowFocused(Self.window))
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.tiler.settings.barEdge = edge
        core.tiler.settings.kiwishelf.thickness = 40
        core.tiler.settings.animations.onWindowResize = false
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return core
    }

    /// The reserved strip on `edge`, required so no clause passes on a
    /// fixture that painted or reserved nothing.
    private func strip(_ core: KiwiCore, edge: AppBarEdge) throws -> CGRect {
        let space = try #require(
            core.state.workspaces.space(of: Self.window)
        )
        return try #require(
            core.reservedStrips(forSpace: space)
                .first { $0.edge == edge }?.strip,
            "no reserved \(edge) strip"
        )
    }

    private func middle(_ screen: NSScreen) -> CGRect {
        CGRect(
            x: screen.frame.midX - 200,
            y: screen.frame.midY - 150,
            width: 400,
            height: 300
        )
    }

    @Test(
        "move_floating runs past a bottom bar to the screen edge",
        .enabled(if: NSScreen.main != nil)
    )
    func moveReachesTheScreenEdge() throws {
        let screen = try #require(NSScreen.screens.first)
        let core = try #require(
            makeBarredCore(edge: .bottom, frame: middle(screen))
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let bar = try strip(core, edge: .bottom)

        core.execute("move_floating", args: [.string("y"), .number(5000)])

        let moved = try #require(
            core.tiler.recentInstantTarget(Self.window)
        )
        #expect(moved.maxY > bar.minY)
        #expect(moved.maxY == screen.frame.maxY)
    }

    /// Holds the push half of the rule: a step up ends below the top
    /// bar. The push in `floatMoveFrame` would rescue a reach that
    /// lost its top carve, so this pins the outcome, not the carve.
    @Test(
        "move_floating still stops below a top bar",
        .enabled(if: NSScreen.main != nil)
    )
    func moveStopsBelowATopBar() throws {
        let screen = try #require(NSScreen.screens.first)
        let core = try #require(
            makeBarredCore(edge: .top, frame: middle(screen))
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let bar = try strip(core, edge: .top)

        core.execute("move_floating", args: [.string("y"), .number(-5000)])

        let moved = try #require(
            core.tiler.recentInstantTarget(Self.window)
        )
        #expect(moved.minY >= bar.maxY)
    }

    @Test(
        "A float grows under a side bar to the screen edge",
        .enabled(if: NSScreen.main != nil)
    )
    func growReachesTheScreenEdge() throws {
        let screen = try #require(NSScreen.screens.first)
        let core = try #require(
            makeBarredCore(edge: .right, frame: middle(screen))
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let bar = try strip(core, edge: .right)

        core.execute("resize", args: [.string("x"), .number(5000)])

        let grown = try #require(
            core.tiler.recentInstantTarget(Self.window)
        )
        #expect(grown.maxX > bar.minX)
        #expect(grown.maxX == screen.frame.maxX - core.floatRingInset)
    }
}
