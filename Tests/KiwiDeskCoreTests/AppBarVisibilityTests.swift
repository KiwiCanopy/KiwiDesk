import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Each App Bar item carries where its window sits (#2234), judged
/// from the frames the retile issues and the order KiwiDesk
/// intends: the dim reads it, so a lit item is one whose focus
/// moves nothing.
@Suite("App Bar visibility", .serialized)
@MainActor
struct AppBarVisibilityTests {
    private static let bounds = CGRect(
        x: 0,
        y: 0,
        width: 1000,
        height: 800
    )

    private func makeCore(
        mode: String,
        windows: [ManagedWindow]
    ) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-bar-visibility-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.execute("set_mode", args: [.string("1"), .string(mode)])
        for window in windows {
            core.state.apply(.windowCreated(window))
        }
        return core
    }

    private func verdicts(
        _ core: KiwiCore
    ) throws -> [WindowID: BarVisibility] {
        let space = try #require(core.activeSpace)
        let app = try #require(
            core.appBarContent(space: space, settings: core.tiler.settings)
        )
        return Dictionary(
            uniqueKeysWithValues: app.items.map { ($0.id, $0.visibility) }
        )
    }

    private func window(_ id: UInt32, floating: Bool = false)
        -> ManagedWindow
    {
        ManagedWindow(
            id: WindowID(id),
            pid: Int32(900_000 + id),
            appName: "App\(id)",
            isFloating: floating
        )
    }

    @Test("Monocle: the focus is visible, the rest hidden")
    func monocleHidesTheRest() throws {
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), window(2)]
        )
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(1)] == .visible)
        #expect(seen[WindowID(2)] == .hidden)
    }

    @Test("A float over a tile leaves the tile lit")
    func floatCoversNoTile() throws {
        var float = window(3, floating: true)
        float.frame = CGRect(x: 100, y: 100, width: 300, height: 200)
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), float]
        )
        core.state.apply(.windowFocused(WindowID(3)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(1)] == .visible)
        #expect(seen[WindowID(3)] == .visible)
    }

    @Test("Scrolling: a column past the edge shows its near side")
    func scrollingCutNamesTheSide() throws {
        let core = try makeCore(
            mode: "scrolling",
            windows: [window(1), window(2), window(3)]
        )
        core.execute("scroll.set_slot_size", args: [.number(700)])
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(1)] == .visible)
        #expect(seen[WindowID(2)] == .partly(shown: .left))
        // Past it, the row's edge sliver is no part worth a moon.
        #expect(seen[WindowID(3)] == .hidden)
    }

    /// Monocle reads its front member, not frames: the held member
    /// stays lit while a float holds the focus.
    @Test("Monocle with a float focused keeps its held member lit")
    func monocleFloatFocusKeepsTheHold() throws {
        var float = window(3, floating: true)
        float.frame = CGRect(x: 100, y: 100, width: 300, height: 200)
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), window(2), float]
        )
        core.state.apply(.windowFocused(WindowID(2)))
        core.retile()
        core.state.apply(.windowFocused(WindowID(3)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(1)] == .hidden)
        #expect(seen[WindowID(2)] == .visible)
    }

    /// The focused window sits above every float (#2284): a float it
    /// covers wholly reads hidden, one it overlaps reads partly with
    /// no side, one clear of it lit, and one the screen's edge cuts
    /// hidden — never a half-moon.
    @Test("A float reads by the focused window over it")
    func floatUnderTheFocus() throws {
        let frames: [UInt32: CGRect] = [
            3: CGRect(x: 100, y: 100, width: 200, height: 150),
            4: CGRect(x: 550, y: 300, width: 300, height: 200),
            5: CGRect(x: 760, y: 100, width: 180, height: 150),
            6: CGRect(x: 900, y: 600, width: 400, height: 150),
        ]
        let floats = frames.keys.sorted().map { id -> ManagedWindow in
            var float = window(id, floating: true)
            float.frame = frames[id]!
            return float
        }
        let core = try makeCore(
            mode: "scrolling",
            windows: [window(1), window(2)] + floats
        )
        core.execute("scroll.set_slot_size", args: [.number(700)])
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(3)] == .hidden)
        #expect(seen[WindowID(4)] == .partly(shown: nil))
        #expect(seen[WindowID(5)] == .visible)
        #expect(seen[WindowID(6)] == .hidden)
        // No float counts against a tile: float 3 sits wholly inside
        // tile 1, which stays lit.
        #expect(seen[WindowID(1)] == .visible)
    }

    /// A focused float sits above the other floats; on a Space no
    /// screen has active there is no system focus, so nothing covers
    /// a float.
    @Test("A focused float covers the other floats")
    func focusedFloatCoversFloats() throws {
        var top = window(3, floating: true)
        top.frame = CGRect(x: 100, y: 100, width: 400, height: 300)
        var under = window(4, floating: true)
        under.frame = CGRect(x: 150, y: 150, width: 100, height: 100)
        let core = try makeCore(
            mode: "scrolling",
            windows: [window(1), top, under]
        )
        core.state.apply(.windowFocused(WindowID(3)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(3)] == .visible)
        #expect(seen[WindowID(4)] == .hidden)
    }

    @Test("A float's own move refreshes the bars")
    func floatMoveRefreshesTheBars() throws {
        var float = window(3, floating: true)
        float.frame = CGRect(x: 100, y: 100, width: 300, height: 200)
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), float]
        )
        #expect(core.appBarListsShownFloat(WindowID(3)))
        #expect(!core.appBarListsShownFloat(WindowID(1)))
        core.handleFloatGeometryForBars(WindowID(1))
        #expect(core.deferred.task(for: .barVisibilityRefresh) == nil)
        // Through the event arms, not only the door.
        let moved = CGRect(x: 300, y: 300, width: 300, height: 200)
        core.handle(.windowMoved(WindowID(3), moved))
        #expect(core.deferred.task(for: .barVisibilityRefresh) != nil)
        core.deferred.cancel(.barVisibilityRefresh)
        core.handle(.windowResized(WindowID(3), moved))
        #expect(core.deferred.task(for: .barVisibilityRefresh) != nil)
    }
}
