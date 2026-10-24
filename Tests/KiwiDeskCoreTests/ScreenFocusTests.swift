import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `focus_display_last` and `focus_display <direction>` (#2512) on
/// pinned screens: A, B and C left to right, a fourth D below B, and
/// each screen showing its own Space ("1" to "4"). No `NSScreen`
/// backs them; the screen hop reads the injected frames.
@Suite("Focus another screen (#2512)", .serialized)
@MainActor
struct ScreenFocusTests {
    private static let a = DisplayID(9_101)
    private static let b = DisplayID(9_102)
    private static let c = DisplayID(9_103)
    private static let d = DisplayID(9_104)

    private static let frames: [ScreenHop.Screen] = [
        (a, CGRect(x: 0, y: 0, width: 1000, height: 800)),
        (b, CGRect(x: 1000, y: 0, width: 1000, height: 800)),
        (c, CGRect(x: 2000, y: 0, width: 1000, height: 800)),
        (d, CGRect(x: 1000, y: 800, width: 1000, height: 800)),
    ]

    private func makeCore(screens count: Int) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-screen-focus-\(UUID().uuidString)"
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
        return core
    }

    private func screen(_ core: KiwiCore) -> DisplayID? {
        core.focusedScreen
    }

    @Test("with two screens and nothing recorded it goes to the other")
    func twoScreensToggle() {
        let core = makeCore(screens: 2)
        #expect(core.execute("focus_display_last").isSuccess)
        #expect(screen(core) == Self.b)
        #expect(core.execute("focus_display_last").isSuccess)
        #expect(screen(core) == Self.a)
    }

    @Test("with three it returns to the one before, and refuses at first")
    func threeScreensReturn() {
        let core = makeCore(screens: 3)
        #expect(!core.execute("focus_display_last").isSuccess)
        #expect(screen(core) == Self.a)
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("3")])
        #expect(core.execute("focus_display_last").isSuccess)
        #expect(screen(core) == Self.b)
        #expect(core.execute("focus_display_last").isSuccess)
        #expect(screen(core) == Self.c)
    }

    /// A recorded screen since unplugged is passed over for the one
    /// before it, never targeted.
    @Test("an unplugged screen leaves the trail")
    func unpluggedScreenIsSkipped() {
        let core = makeCore(screens: 3)
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("3")])
        core.state.workspaces.removeDisplay(Self.b)
        let left = Self.frames.filter { $0.id != Self.b }
        core.tiler.displayFrames = { left }
        #expect(core.execute("focus_display_last").isSuccess)
        #expect(screen(core) == Self.a)
    }

    /// Each refusal bumps the focused window toward the edge it met
    /// (#436); the last-screen verb's toward the right, by ruling.
    @Test("a refusal bumps the focused window")
    func refusalBumps() {
        let core = makeCore(screens: 1)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 900_001,
                    appName: "App1",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
        )
        core.state.apply(.windowFocused(WindowID(1)))
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        core.execute("focus_display_last")
        core.execute("focus_display", args: [.string("up")])
        #expect(bumps == [.right, .up])
    }

    @Test("one screen has no other")
    func oneScreenRefuses() {
        let core = makeCore(screens: 1)
        let response = core.execute("focus_display_last")
        #expect(!response.isSuccess)
        #expect(response.error == "no other screen")
    }

    @Test("a direction takes the nearest screen that way and stops")
    func directionStops() {
        let core = makeCore(screens: 4)
        #expect(
            core.execute("focus_display", args: [.string("right")])
                .isSuccess
        )
        #expect(screen(core) == Self.b)
        #expect(
            core.execute("focus_display", args: [.string("down")])
                .isSuccess
        )
        #expect(screen(core) == Self.d)
        // C sits up and to the right of D: a diagonal, no neighbour.
        #expect(
            !core.execute("focus_display", args: [.string("right")])
                .isSuccess
        )
        #expect(screen(core) == Self.d)
        core.execute("focus_display", args: [.string("up")])
        core.execute("focus_display", args: [.string("right")])
        #expect(
            !core.execute("focus_display", args: [.string("right")])
                .isSuccess
        )
        #expect(screen(core) == Self.c)
    }

    @Test("a screen keeps the Space it shows, an empty one included")
    func showsNoOtherSpace() {
        let core = makeCore(screens: 2)
        core.state.workspaces.assign(SpaceID("5"), to: Self.b)
        #expect(core.state.workspaces.activeSpace(on: Self.b) == "2")
        core.execute("focus_display", args: [.string("right")])
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        #expect(core.state.workspaces.activeSpace(on: Self.a) == "1")
    }

    @Test("the direction is read from the type")
    func directionIsTyped() {
        let core = makeCore(screens: 2)
        #expect(
            !core.execute("focus_display", args: [.string("next")])
                .isSuccess
        )
    }
}
