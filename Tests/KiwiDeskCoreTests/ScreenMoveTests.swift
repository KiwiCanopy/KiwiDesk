import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `move_to_display_last`, `move_to_display <direction>` and their
/// `_and_follow` forms (#3117) on pinned screens: A, B and C left
/// to right, each showing its own Space ("1" to "3"), the window
/// under test focused in Space 1 on A. Every target Space starts
/// empty, the case a Lua script cannot reach.
@Suite("Move a window to another screen (#3117)", .serialized)
@MainActor
struct ScreenMoveTests {
    private static let a = DisplayID(9_201)
    private static let b = DisplayID(9_202)
    private static let c = DisplayID(9_203)
    private static let window = WindowID(1)

    private static let frames: [ScreenHop.Screen] = [
        (a, CGRect(x: 0, y: 0, width: 1000, height: 800)),
        (b, CGRect(x: 1000, y: 0, width: 1000, height: 800)),
        (c, CGRect(x: 2000, y: 0, width: 1000, height: 800)),
    ]

    private func makeCore(
        screens count: Int,
        sticky: StickyScope = .none
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-screen-move-\(UUID().uuidString)"
                )
        )
        let used = Array(Self.frames.prefix(count))
        core.tiler.displayFrames = { used }
        for (index, screen) in used.enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(id: screen.id, name: "S\(index)", frame: screen.frame)
            )
            let space = SpaceID("\(index + 1)")
            core.state.workspaces.assign(space, to: screen.id)
            core.state.workspaces.activate(space)
        }
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 900_101,
                    appName: "App1",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300),
                    stickyScope: sticky
                )
            )
        )
        core.state.apply(.windowFocused(Self.window))
        return core
    }

    private func home(_ core: KiwiCore) -> SpaceID? {
        core.state.workspaces.space(of: Self.window)
    }

    @Test("a move without follow files the window and stays put")
    func moveStays() {
        let core = makeCore(screens: 2)
        #expect(core.execute("move_to_display_last").isSuccess)
        #expect(home(core) == SpaceID("2"))
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        #expect(core.focusedScreen == Self.a)
    }

    @Test("a follow goes with it, and pressing again sends it back")
    func followToggles() {
        let core = makeCore(screens: 3)
        core.execute("focus_space", args: [.string("3")])
        core.execute("focus_space", args: [.string("1")])
        let verb = "move_to_display_last_and_follow"
        #expect(core.execute(verb).isSuccess)
        #expect(home(core) == SpaceID("3"))
        #expect(core.focusedScreen == Self.c)
        #expect(core.execute(verb).isSuccess)
        #expect(home(core) == SpaceID("1"))
        #expect(core.focusedScreen == Self.a)
    }

    /// Without follow the history stays, so the next window goes to
    /// the same screen.
    @Test("successive moves without follow aim at the same screen")
    func staysAimed() {
        let core = makeCore(screens: 3)
        core.execute("focus_space", args: [.string("3")])
        core.execute("focus_space", args: [.string("1")])
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 900_102,
                    appName: "App2",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
        )
        #expect(core.execute("move_to_display_last").isSuccess)
        core.state.apply(.windowFocused(WindowID(2)))
        #expect(core.execute("move_to_display_last").isSuccess)
        #expect(home(core) == SpaceID("3"))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "3")
    }

    @Test("a direction takes the screen focus_display would")
    func directionMatchesFocus() {
        let core = makeCore(screens: 3)
        #expect(core.screenAhead(.right) == Self.b)
        #expect(
            core.execute("move_to_display", args: [.string("right")])
                .isSuccess
        )
        #expect(home(core) == SpaceID("2"))
        #expect(core.focusedScreen == Self.a)
        let follow = makeCore(screens: 3)
        #expect(
            follow.execute(
                "move_to_display_and_follow",
                args: [.string("right")]
            ).isSuccess
        )
        #expect(home(follow) == SpaceID("2"))
        #expect(follow.focusedScreen == Self.b)
    }

    @Test("no screen that way refuses, bumps and moves nothing")
    func edgeRefuses() {
        let core = makeCore(screens: 2)
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        let response = core.execute(
            "move_to_display",
            args: [.string("left")]
        )
        #expect(response.error == "no screen left of focus")
        #expect(home(core) == SpaceID("1"))
        #expect(bumps == [.left])
    }

    @Test("one screen has no other")
    func oneScreenRefuses() {
        let core = makeCore(screens: 1)
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        let response = core.execute("move_to_display_last_and_follow")
        #expect(response.error == "no other screen")
        #expect(home(core) == SpaceID("1"))
        #expect(bumps == [.right])
    }

    /// A screen reached with no command behind it is in no history
    /// until the press records it, so the toggle depends on that
    /// record.
    @Test("the press records the screen it leaves")
    func pressRecordsItsScreen() {
        let core = makeCore(screens: 3)
        core.execute("focus_space", args: [.string("3")])
        core.state.workspaces.activate(SpaceID("1"))
        let verb = "move_to_display_last_and_follow"
        #expect(core.execute(verb).isSuccess)
        #expect(core.focusedScreen == Self.c)
        #expect(core.execute(verb).isSuccess)
        #expect(home(core) == SpaceID("1"))
        #expect(core.focusedScreen == Self.a)
    }

    @Test("the direction is read from the type")
    func directionIsTyped() {
        let core = makeCore(screens: 2)
        #expect(
            !core.execute("move_to_display", args: [.string("next")])
                .isSuccess
        )
        #expect(home(core) == SpaceID("1"))
    }

    /// A global sticky window shows on every screen, so no move
    /// takes it; the sticky gate answers with its pill.
    @Test("a global sticky window stays")
    func globalStickyStays() {
        let core = makeCore(screens: 2, sticky: .global)
        core.execute("move_to_display_last")
        #expect(home(core) == SpaceID("1"))
    }
}
