import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #2619 tie rule through the real `focus` / `swap` verbs:
/// Stack's master into its stack, and Track's step across tracks.
@Suite("Navigation tie commands (#2619)", .serialized)
@MainActor
struct NavigationTieCommandTests {
    private static let display = CGRect(
        x: 0,
        y: 0,
        width: 1920,
        height: 1080
    )

    private func makeCore() -> KiwiCore {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-nav-tie-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in Self.display }
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.tiler.settings.monocle.appBar.visibility = .hidden
        core.tiler.settings.scrolling.appBar.visibility = .hidden
        core.execute("set_focus_wrap", args: [.string("off")])
        return core
    }

    private func add(_ count: Int, to core: KiwiCore) {
        for id in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
    }

    /// Four windows in Stack: `.first` placement leaves the row
    /// [4, 3, 2, 1] — master 4, the stack 3, 2, 1 from the top.
    private func stackCore() -> (KiwiCore, SpaceID) {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        add(4, to: core)
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(4), in: space)
        return (core, space)
    }

    /// Track, one window per track seeded, then merged so the
    /// listed heads start the tracks.
    private func trackCore(
        windows count: Int,
        heads: [WindowID],
        focus: WindowID
    ) -> KiwiCore {
        let core = makeCore()
        add(count, to: core)
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        core.state.workspaces.withSpace(space) {
            $0.trackBreaks = Set(heads)
        }
        core.retile()
        core.state.workspaces.focus(focus, in: space)
        return core
    }

    @Test("The master steps into the stack's first window")
    func masterEntersAtTheTop() {
        let (core, space) = stackCore()
        #expect(
            core.state.workspaces[space]?.windows
                == [4, 3, 2, 1].map { WindowID($0) }
        )
        #expect(
            core.execute("focus", args: [.string("right")]).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(3))
    }

    @Test("A step back into the stack returns where it came from")
    func roundTripReturns() {
        let (core, _) = stackCore()
        core.rememberHonoredFocus(WindowID(1))
        core.rememberHonoredFocus(WindowID(4))
        #expect(
            core.execute("focus", args: [.string("right")]).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("A swap takes the first window, never the last step")
    func swapIgnoresHistory() {
        let (core, space) = stackCore()
        core.rememberHonoredFocus(WindowID(1))
        core.rememberHonoredFocus(WindowID(4))
        #expect(
            core.execute("swap", args: [.string("right")]).isSuccess
        )
        #expect(
            core.state.workspaces[space]?.windows
                == [3, 4, 2, 1].map { WindowID($0) }
        )
    }

    @Test("Across tracks, top maps to top and bottom to bottom")
    func trackMapsByCentre() {
        // Tracks [1, 2] and [3, 4, 5].
        let heads = [WindowID(1), WindowID(3)]
        let bottom = trackCore(windows: 5, heads: heads, focus: WindowID(2))
        #expect(
            bottom.execute("focus", args: [.string("right")]).isSuccess
        )
        #expect(bottom.activeSpace?.focused == WindowID(5))
        let top = trackCore(windows: 5, heads: heads, focus: WindowID(1))
        #expect(
            top.execute("focus", args: [.string("right")]).isSuccess
        )
        #expect(top.activeSpace?.focused == WindowID(3))
    }

    @Test("A lone track enters the next at its first window")
    func loneTrackTakesTheFirst() {
        // Tracks [1] and [2, 3, 4].
        let heads = [WindowID(1), WindowID(2)]
        let core = trackCore(windows: 4, heads: heads, focus: WindowID(1))
        #expect(
            core.execute("focus", args: [.string("right")]).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("A lone track's step back returns where it came from")
    func loneTrackRoundTrip() {
        let heads = [WindowID(1), WindowID(2)]
        let core = trackCore(windows: 4, heads: heads, focus: WindowID(1))
        core.rememberHonoredFocus(WindowID(4))
        core.rememberHonoredFocus(WindowID(1))
        #expect(
            core.execute("focus", args: [.string("right")]).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(4))
    }
}
