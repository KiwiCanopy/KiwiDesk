import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// The replay's edges for #1864's carried floats: a late hand float
/// whose record is a stash corner still floats on arrival, and is
/// never delivered there (#1352); and a tiled window of a Space in
/// floating mode replays as the float it is (#1178).
@Suite("A replayed float's edges (#1864)", .serialized)
@MainActor
struct QuitFloatReplayEdgeTests: CrossSessionFixture {
    private static let tile = WindowID(1)
    private static let float = WindowID(2)
    private static let hiddenTile = WindowID(11)

    private static let windows: [F.Window] = [
        .init(
            id: tile,
            space: F.shown,
            frame: CGRect(x: 40, y: 60, width: 700, height: 500)
        ),
        .init(
            id: float,
            space: F.shown,
            frame: CGRect(x: 210, y: 230, width: 420, height: 310)
        ),
        .init(
            id: hiddenTile,
            space: F.hidden,
            frame: CGRect(x: 120, y: 140, width: 640, height: 480)
        ),
    ]

    /// The stash corner `frame` parks at on the fixture's screen.
    private func corner(_ frame: CGRect, in core: KiwiCore) throws -> CGRect {
        let bounds = try #require(core.tiler.allScreenBounds().first)
        let parked = TilingEngine.stashFrame(
            frame,
            in: bounds,
            corner: .bottomRight
        )
        #expect(core.tiler.looksStashed(parked))
        return parked
    }

    /// A Quit's file, through `CrashRecovery`'s own stop and read.
    private func quit(_ core: KiwiCore) throws -> StateSnapshot {
        core.crash.loginSession = { 1 }
        core.crash.bootTime = { .distantPast }
        core.crash.autosave()
        core.crash.shutdownCleanly()
        return try #require(core.crash.takeBootSnapshot())
    }

    @Test(
        "a late float whose record is a corner floats, undelivered",
        .enabled(if: NSScreen.main != nil)
    )
    func lateCornerFloatFloats() throws {
        let a = try #require(F.processA(Self.windows))
        a.onLog = { _ in }
        a.state.setFloating(Self.float, true)
        let left = F.settle(a)
        var session = try quit(a)
        let index = try #require(
            session.windows.firstIndex { $0.windowID == Self.float }
        )
        #expect(session.windows[index].floating == true)
        session.windows[index].frame = try corner(left[Self.float]!, in: a)
        let early = Self.windows.filter { $0.id != Self.float }
        let (b, _) = try #require(
            F.processB(early, left: left, session: session)
        )
        b.onLog = { _ in }
        var arrival = try #require(Self.windows.first { $0.id == Self.float })
        arrival.frame = left[Self.float]!
        b.handle(.windowCreated(F.managed(arrival)))
        #expect(b.state.userFloated.contains(Self.float))
        #expect(b.tiler.stashOriginal(Self.float) == nil)
    }

    @Test(
        "a cross-session arrival whose record is a corner floats, undelivered",
        .enabled(if: NSScreen.main != nil)
    )
    func crossSessionCornerFloatFloats() throws {
        let core = try #require(boot([]))
        var desk = previous([(F.hidden, "app.zen", "Zen Browser")])
        let parked = try corner(Self.recorded, in: core)
        desk.windows[0].frame = parked
        desk.windows[0].floating = true
        leave(desk, in: core)
        arrange(core)
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        #expect(space(core, 30) == F.hidden)
        #expect(core.state.userFloated.contains(WindowID(30)))
        // Parked on its hidden Space at the frame it arrived with,
        // never at the record's corner.
        #expect(core.tiler.stashOriginal(WindowID(30)) == Self.frame)
        #expect(core.tiler.stashOriginal(WindowID(30)) != parked)
    }

    /// A Space in floating mode lays nothing out, so its tiled-flag
    /// window replays as a float: the quit grid's frame never
    /// becomes the original the park keeps.
    @Test(
        "a floating-mode Space's tiled window replays as a float",
        .enabled(if: NSScreen.main != nil)
    )
    func floatingModeMemberReplaysAsAFloat() throws {
        let a = try #require(F.processA(Self.windows))
        a.onLog = { _ in }
        a.setSpaceMode(F.hidden, .floating)
        _ = F.settle(a)
        #expect(a.state.windows[Self.hiddenTile]?.isFloating == false)
        let capture = try #require(a.tiler.stashOriginal(Self.hiddenTile))
        var left = F.settle(a)
        let grid = WindowGather.targets(
            state: a.state,
            primaryHeight: GeometryUtils.primaryHeight,
            style: .grid,
            minSize: a.tiler.settings.minWindowSize,
            targetDepth: a.appWide.quitGridTargetDepth
        )
        left.merge(grid) { _, gathered in gathered }
        #expect(left[Self.hiddenTile] != capture)
        let session = try quit(a)
        let (b, _) = try #require(
            F.processB(Self.windows, left: left, session: session)
        )
        #expect(b.state.workspaces[F.hidden]?.mode == .floating)
        #expect(b.tiler.stashOriginal(Self.hiddenTile) == capture)
    }
}
