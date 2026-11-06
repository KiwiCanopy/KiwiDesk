import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(x: 0, y: 25, width: 1600, height: 1000)
private let home = SpaceID("1")
private let here = SpaceID("2")
private let sticky = WindowID(1)
private let homeTile = WindowID(2)
private let tile = WindowID(3)
private let float = WindowID(4)

/// Space 1 holds the global sticky window and a tile, Space 2 a tile
/// and is active, with the sticky window its focused traveler.
@MainActor
private func makeCore() -> KiwiCore {
    let core = makeTestCore()
    core.tiler.visibleBounds = { _ in bounds }
    for id in [sticky, homeTile] {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: id, pid: 900_001, appName: "A")
            )
        )
    }
    core.execute("set_mode", args: [.string("1"), .string("bsp")])
    core.execute("set_mode", args: [.string("2"), .string("bsp")])
    core.state.workspaces.activate(here)
    core.state.apply(
        .windowCreated(ManagedWindow(id: tile, pid: 900_002, appName: "B"))
    )
    core.state.setSticky(sticky, .global)
    core.state.workspaces.focus(tile, in: here)
    core.state.workspaces.focus(sticky, in: home)
    return core
}

@MainActor
private func maximized(_ core: KiwiCore, on id: SpaceID = here) -> WindowID? {
    core.state.workspaces[id].flatMap {
        core.state.maximizedWindow(of: $0)
    }
}

/// A sticky window's maximize sits on the Space it renders on and
/// ends when it leaves that Space (#3035).
@Suite("Maximize a sticky window (#3035)", .serialized)
@MainActor
struct MaximizeStickyWindowTests {
    @Test("A traveler fills the screen, its flag on the Space it draws on")
    func travelerFills() {
        let core = makeCore()
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(core.state.workspaces[here]?.maximized == sticky)
        #expect(core.state.workspaces[home]?.maximized == nil)
        #expect(maximized(core) == sticky)
        #expect(
            core.tiler.placedFrames(state: core.state)[sticky] == bounds
        )
        #expect(
            core.tiler.calculatedFrames(state: core.state)[sticky] != bounds
        )
    }

    @Test("A second press puts it back")
    func secondPressRestores() {
        let core = makeCore()
        core.execute("toggle_maximized")
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(core.state.workspaces[here]?.maximized == nil)
    }

    @Test("On its home Space it fills like any member")
    func homeFills() {
        let core = makeCore()
        core.state.workspaces.activate(home)
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(maximized(core, on: home) == sticky)
    }

    @Test("Leaving the Space ends it, and coming back does not restore it")
    func spaceSwitchEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.workspaces.activate(home)
        core.retile()
        #expect(core.state.workspaces[here]?.maximized == nil)
        #expect(core.state.workspaces[home]?.maximized == nil)
        core.state.workspaces.activate(here)
        core.retile()
        #expect(maximized(core) == nil)
    }

    @Test("Focus on a tile of the Space ends it, for good")
    func focusOnTileEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.workspaces.focus(tile, in: here)
        #expect(maximized(core) == nil)
        core.retile()
        core.state.workspaces.focus(sticky, in: home)
        #expect(maximized(core) == nil)
    }

    @Test("Focus on a float of the Space keeps it")
    func focusOnFloatKeeps() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: float, pid: 900_003, appName: "C")
            )
        )
        core.state.windows.setFloating(float, true)
        core.state.workspaces.focus(float, in: here)
        core.retile()
        #expect(maximized(core) == sticky)
    }

    @Test("A dialog closing over it hands focus back to it")
    func dialogCloseKeeps() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: float, pid: 900_003, appName: "C")
            )
        )
        core.state.windows.setFloating(float, true)
        core.state.workspaces.focus(float, in: here)
        core.state.apply(.windowDestroyed(float, wasMinimized: false))
        #expect(core.state.workspaces.lastFocused == sticky)
        #expect(core.focusedWindowID == sticky)
        core.retile()
        #expect(maximized(core) == sticky)
    }

    @Test("A window closing while focus is elsewhere moves no focus")
    func unfocusedCloseLeavesFocus() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: float, pid: 900_003, appName: "C")
            )
        )
        core.state.windows.setFloating(float, true)
        core.state.workspaces.focus(float, in: here)
        core.state.workspaces.focus(homeTile, in: home)
        core.state.apply(.windowDestroyed(float, wasMinimized: false))
        #expect(core.state.workspaces.lastFocused == homeTile)
    }

    @Test("Focus on another screen keeps a display sticky's maximize")
    func otherScreenFocusKeeps() {
        let core = makeCore()
        core.state.workspaces.assign(here, to: DisplayID(1))
        core.state.workspaces.assign(home, to: DisplayID(1))
        core.state.workspaces.assign(SpaceID("3"), to: DisplayID(2))
        core.state.setSticky(sticky, .display)
        core.execute("toggle_maximized")
        #expect(maximized(core) == sticky)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: float,
                    pid: 900_003,
                    appName: "C"
                )
            )
        )
        core.state.workspaces.add(float, to: SpaceID("3"))
        core.state.workspaces.focus(float, in: SpaceID("3"))
        #expect(maximized(core) == sticky)
    }

    @Test("Closing it ends it, though the flag is not on its home")
    func closeEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.apply(.windowDestroyed(sticky, wasMinimized: false))
        #expect(maximized(core) == nil)
        core.retile()
        #expect(core.state.workspaces[here]?.maximized == nil)
    }

    @Test("Minimizing it ends it, though the flag is not on its home")
    func minimizeEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.apply(.windowDestroyed(sticky, wasMinimized: true))
        #expect(maximized(core) == nil)
        core.retile()
        #expect(core.state.workspaces[here]?.maximized == nil)
    }

    @Test("A drag of the traveler ends it")
    func dragEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        #expect(core.endMaximize(of: sticky))
        #expect(core.state.workspaces[here]?.maximized == nil)
    }

    @Test("Turning sticky off sends it home and ends it")
    func unstickEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.setSticky(sticky, .none)
        #expect(maximized(core) == nil)
    }

    @Test("A floating sticky window is still refused")
    func floatingStickyRefused() {
        let core = makeCore()
        core.state.windows.setFloating(sticky, true)
        #expect(!core.execute("toggle_maximized").isSuccess)
        #expect(core.state.workspaces[here]?.maximized == nil)
    }

    @Test("A traveler replaces a member's maximize on its Space")
    func onePerSpace() {
        let core = makeCore()
        core.state.workspaces.focus(tile, in: here)
        core.execute("toggle_maximized")
        #expect(maximized(core) == tile)
        core.state.workspaces.focus(sticky, in: home)
        #expect(maximized(core) == nil)
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(maximized(core) == sticky)
    }
}
