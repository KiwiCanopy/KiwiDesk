import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A float is never resized to fit, and only a TOP bar moves one
/// (#3163, owner ruling 2026-11-10). The push clear of a top strip
/// is `FloatingModeBarClampTests`'; this suite holds the other
/// half: a bottom bar moves no float on the sweep, the drop or the
/// unsolicited-resize arm, and a drop under a top bar keeps its
/// size.
@Suite("Floats never resized (#3163)", .serialized)
@MainActor
struct FloatNeverResizedTests {
    private static let window = WindowID(1)

    /// A core showing a Space Bar on `edge` over one floating
    /// space, holding one window at `frame`. Nil where the host has
    /// no screen to paint on.
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
                    pid: 1,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: true
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.window)!
        core.state.workspaces.setMode(space, .floating)
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.tiler.settings.barEdge = edge
        core.tiler.settings.kiwishelf.thickness = 40
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return core
    }

    /// The painted strip, required on `edge` and reserved, so a
    /// clause below cannot pass on a fixture that painted nothing
    /// or reserved nothing.
    private func reservedStrip(
        _ core: KiwiCore,
        edge: AppBarEdge
    ) throws -> CGRect {
        let space = try #require(
            core.state.workspaces.space(of: Self.window)
        )
        let strips = core.reservedStrips(forSpace: space)
        return try #require(
            strips.first { $0.edge == edge }?.strip,
            "no reserved \(edge) strip — the clause would be vacuous"
        )
    }

    /// A frame reaching past the bottom strip by 200 pt, as tall
    /// as the screen is, so a fit or a lift would each change it.
    private func overBottom(_ screen: NSScreen) -> CGRect {
        CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY + 300,
            width: 600,
            height: screen.frame.height - 100
        )
    }

    @Test(
        "The sweep moves no float under a bottom bar",
        .enabled(if: NSScreen.main != nil)
    )
    func sweepLeavesABottomOverlap() throws {
        let screen = try #require(NSScreen.screens.first)
        let frame = overBottom(screen)
        let core = try #require(
            makeBarredCore(edge: .bottom, frame: frame)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let strip = try reservedStrip(core, edge: .bottom)
        #expect(frame.maxY > strip.minY)

        core.clampFloatsClearOfBars()

        #expect(core.tiler.recentInstantTarget(Self.window) == nil)
        #expect(core.floatBarPush(Self.window, frame: frame) == nil)
    }

    @Test(
        "A drop past a bottom bar keeps its frame",
        .enabled(if: NSScreen.main != nil)
    )
    func dropPastABottomBarKeepsItsFrame() throws {
        let screen = try #require(NSScreen.screens.first)
        let frame = overBottom(screen)
        let core = try #require(
            makeBarredCore(edge: .bottom, frame: frame)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        _ = try reservedStrip(core, edge: .bottom)
        #expect(core.dropLandsUnmanaged(Self.window))

        core.handleDragEnd(Self.window, start: frame, frame: frame)

        #expect(core.tiler.recentInstantTarget(Self.window) == nil)
    }

    @Test(
        "A drop under a top bar is pushed down at its own size",
        .enabled(if: NSScreen.main != nil)
    )
    func dropUnderATopBarKeepsItsSize() throws {
        // Taller than the room below the strip: pushed whole, its
        // bottom running off the screen.
        let screen = try #require(NSScreen.screens.first)
        let frame = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY,
            width: 600,
            height: screen.frame.height
        )
        let core = try #require(
            makeBarredCore(edge: .top, frame: frame)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let strip = try reservedStrip(core, edge: .top)

        core.handleDragEnd(Self.window, start: frame, frame: frame)

        let commanded = try #require(
            core.tiler.recentInstantTarget(Self.window),
            "the drop left the title bar under the top strip"
        )
        #expect(commanded.minY >= strip.maxY)
        #expect(commanded.size == frame.size)
        #expect(commanded.minX == frame.minX)
    }
}
