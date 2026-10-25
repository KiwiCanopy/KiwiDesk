import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket (#2446): one key pockets the focused window, takes
/// it out and puts it back. Pocketed, the window is tracked but in
/// no Space; out, it is a float on every Space.
@Suite("Pocket command", .serialized)
@MainActor
struct PocketCommandTests {
    private let one = WindowID(1)
    private let two = WindowID(2)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-pocket-\(UUID().uuidString)")
        )
        for raw: UInt32 in [2, 1] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "App\(raw)",
                        title: "Window \(raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        core.state.apply(.windowFocused(one))
        return core
    }

    private func isFiled(_ core: KiwiCore, _ id: WindowID) -> Bool {
        core.state.workspaces.space(of: id) != nil
    }

    @Test("the first press pockets the focused window, filed nowhere")
    func pockets() {
        let core = makeCore()
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(!isFiled(core, one))
        #expect(core.state.windows[one]?.isFloating == true)
        #expect(core.state.windows[one]?.stickyScope == StickyScope.none)
        #expect(core.state.pocketPhase(of: two) == nil)
    }

    @Test("the next press takes it out, floating, on every Space")
    func takesOut() {
        let core = makeCore()
        core.execute("pocket")
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(
            core.state.workspaces.space(of: one)
                == core.state.workspaces.activeSpace
        )
        #expect(core.state.windows[one]?.isFloating == true)
        #expect(core.state.windows[one]?.stickyScope == .global)
        #expect(core.state.workspaces.lastFocused == one)
    }

    @Test("a press while out puts it back, focused or not")
    func putsBack() {
        let core = makeCore()
        core.execute("pocket")
        core.execute("pocket")
        core.state.apply(.windowFocused(two))
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(core.state.pocketPhase(of: two) == nil)
        #expect(!isFiled(core, one))
        #expect(isFiled(core, two))
    }

    @Test("an app's exit empties the pocket")
    func appExitEmpties() {
        let core = makeCore()
        core.execute("pocket")
        core.state.apply(.appTerminated(pid: 900_001))
        #expect(core.state.pocket == nil)
    }

    @Test("a hide keeps the pocket, and the unhide files nothing")
    func hideKeeps() {
        let core = makeCore()
        core.execute("pocket")
        core.state.apply(.windowHidden(one))
        #expect(core.state.pocket?.window == one)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: one, pid: 900_001, appName: "App1")
            )
        )
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(!isFiled(core, one))
        #expect(core.state.windows[one]?.isFloating == true)
    }

    @Test("an out window re-adopted keeps its float and scope")
    func outReadoptKeepsFlags() {
        let core = makeCore()
        core.execute("pocket")
        core.execute("pocket")
        core.state.apply(.windowHidden(one))
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: one, pid: 900_001, appName: "App1")
            )
        )
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(core.state.windows[one]?.isFloating == true)
        #expect(core.state.windows[one]?.stickyScope == .global)
    }

    @Test("sticky and float keys are refused on a pocket window")
    func refusals() {
        let core = makeCore()
        core.execute("pocket")
        core.execute("pocket")
        #expect(!core.execute("make_unsticky").isSuccess)
        #expect(!core.execute("toggle_sticky").isSuccess)
        #expect(core.state.windows[one]?.stickyScope == .global)
        #expect(!core.execute("toggle_floating").isSuccess)
        #expect(!core.execute("make_tiled").isSuccess)
        #expect(core.state.windows[one]?.isFloating == true)
        #expect(core.tileRefusal(of: one) == .pocket)
    }

    @Test("a native-tab re-key moves the slot")
    func rekeyFollows() {
        let core = makeCore()
        core.execute("pocket")
        core.state.apply(.windowRekeyed(one, WindowID(9)))
        #expect(core.state.pocket?.window == WindowID(9))
    }

    @Test("a closed pocket window leaves no memory of its flags")
    func closeLeavesNoMemory() {
        let core = makeCore()
        core.execute("pocket")
        core.execute("pocket")
        core.state.apply(.windowDestroyed(one, wasMinimized: false))
        core.state.pocket = nil
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(5),
                    pid: 900_001,
                    appName: "App1",
                    title: "Window 1"
                )
            )
        )
        #expect(
            core.state.windows[WindowID(5)]?.stickyScope
                == StickyScope.none
        )
        #expect(core.state.windows[WindowID(5)]?.isFloating == false)
    }

    @Test("a quit files the pocketed window back as the user's float")
    func quitReleases() {
        let core = makeCore()
        core.execute("pocket")
        core.releasePocketForQuit()
        #expect(core.state.pocket == nil)
        #expect(isFiled(core, one))
        #expect(core.state.windows[one]?.isFloating == true)
        #expect(core.state.userFloated.contains(one))
    }

    @Test("a quit leaves an out window a plain float")
    func quitReleasesOut() {
        let core = makeCore()
        core.execute("pocket")
        core.execute("pocket")
        core.releasePocketForQuit()
        #expect(core.state.pocket == nil)
        #expect(core.state.windows[one]?.stickyScope == StickyScope.none)
        #expect(core.state.windows[one]?.isFloating == true)
    }

    @Test("macOS focusing the pocketed window takes it out")
    func activationTakesOut() {
        let core = makeCore()
        core.execute("pocket")
        // Inside the latch: our own pocketing's echo.
        core.handle(.windowFocused(one))
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        core.wallClock = { Date().addingTimeInterval(5) }
        core.handle(.windowFocused(one))
        #expect(core.state.pocketPhase(of: one) == .out)
    }
}
