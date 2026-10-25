import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #2619 tie at a focus key's last window: the This-screen
/// wrap takes the whole rule, a hop onto another screen the step
/// back alone. The hop resolves the main screen's slots, so a
/// screenless runner skips it.
@Suite("Navigation tie past the edge (#2619)", .serialized)
@MainActor
struct NavigationTieEdgeTests {
    private static let mainFrame = CGRect(
        x: 0,
        y: 25,
        width: 1440,
        height: 875
    )
    private static let leftFrame = CGRect(
        x: -1440,
        y: 25,
        width: 1440,
        height: 875
    )
    private let left = DisplayID(9_999)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-nav-tie-edge-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in Self.mainFrame }
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.tiler.settings.monocle.appBar.visibility = .hidden
        core.tiler.settings.scrolling.appBar.visibility = .hidden
        return core
    }

    private func window(_ id: UInt32, x: CGFloat = 0) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid_t(900_000 + id),
            appName: "App\(id)",
            frame: CGRect(x: x, y: 25, width: 700, height: 875)
        )
    }

    /// Stack on one screen: row [4, 3, 2, 1], master 4 on the
    /// left, the stack 3, 2, 1 from the top on the right — tall
    /// enough that the stack shows all three at the minimum size.
    private func stackCore() -> KiwiCore {
        let core = makeCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        for id in UInt32(1)...4 {
            core.state.apply(.windowCreated(window(id)))
        }
        core.execute("set_focus_wrap", args: [.string("this_screen")])
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(4), in: space)
        return core
    }

    @Test("A wrap from the master enters the stack at its first")
    func wrapTakesTheFirst() {
        let core = stackCore()
        #expect(
            core.execute("focus", args: [.string("left")]).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(3))
    }

    @Test("A wrap back into the stack returns where it came from")
    func wrapReturns() {
        let core = stackCore()
        core.rememberHonoredFocus(WindowID(1))
        core.rememberHonoredFocus(WindowID(4))
        #expect(
            core.execute("focus", args: [.string("left")]).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("A hop back onto a screen returns where it came from")
    func hopReturns() {
        guard let main = ScreenList.all.first?.kiwiDisplayID
        else { return }
        let core = makeCore()
        core.tiler.displayFrames = {
            [(self.left, Self.leftFrame), (main, Self.mainFrame)]
        }
        core.execute(
            "stack.set_stack_position",
            args: [.string("left")]
        )
        core.execute(
            "set_mode",
            args: [.string("2"), .string("stack")]
        )
        core.state.workspaces.assign(SpaceID("1"), to: left)
        core.state.workspaces.assign(SpaceID("2"), to: main)
        // Space 2: master 23 on the right, stack 22 over 21 on the
        // left, the edge a hop from the left screen enters by.
        core.state.workspaces.activate(SpaceID("2"))
        for id in UInt32(21)...23 {
            core.state.apply(.windowCreated(window(id)))
        }
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(11, x: -1440)))
        core.state.apply(.windowFocused(WindowID(11)))
        core.execute("set_focus_wrap", args: [.string("all_screens")])
        core.rememberHonoredFocus(WindowID(21))
        core.rememberHonoredFocus(WindowID(11))
        #expect(
            core.navigate([.string("right")], swapping: false).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        #expect(core.state.workspaces.lastFocused == WindowID(21))
    }
}
