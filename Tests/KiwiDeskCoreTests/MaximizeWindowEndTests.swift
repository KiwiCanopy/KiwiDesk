import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(x: 0, y: 25, width: 1600, height: 1000)
private let space = SpaceID("1")
private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// A bsp Space of three tiled windows on a pinned display, `w1`
/// focused and maximized.
@MainActor
private func makeCore() -> KiwiCore {
    let core = makeTestCore()
    core.tiler.visibleBounds = { _ in bounds }
    for id in [w1, w2, w3] {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: id, pid: 900_001, appName: "A")
            )
        )
    }
    core.execute("set_mode", args: [.string("1"), .string("bsp")])
    core.state.workspaces.focus(w1, in: space)
    core.execute("toggle_maximized")
    return core
}

@MainActor
private func maximized(_ core: KiwiCore) -> WindowID? {
    core.state.workspaces[space].flatMap {
        core.state.maximizedWindow(of: $0)
    }
}

/// What ends a maximize, and what must not (#2448): a write that
/// rearranges the Space ends it at the write, so a refused verb
/// ends nothing; a Desktop departure carries it back.
@Suite("Maximize window endings (#2448)", .serialized)
@MainActor
struct MaximizeWindowEndTests {
    @Test("A refused swap leaves it standing")
    func refusedSwapKeeps() {
        let core = makeCore()
        let response = core.execute("swap", args: [.string("left")])
        #expect(!response.isSuccess)
        #expect(maximized(core) == w1)
    }

    @Test("A layout change of the Space ends it; an unchanged one not")
    func modeWriteEnds() {
        let core = makeCore()
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        #expect(maximized(core) == w1)
        core.execute("set_mode", args: [.string("1"), .string("stack")])
        #expect(maximized(core) == nil)
    }

    @Test("Another Space's layout change leaves it standing")
    func otherSpaceModeKeeps() {
        let core = makeCore()
        core.execute("set_mode", args: [.string("9"), .string("stack")])
        #expect(maximized(core) == w1)
    }

    @Test("A dialog closing over it hands focus back to it")
    func dialogCloseKeeps() {
        let core = makeCore()
        core.state.windows.setFloating(w3, true)
        core.state.workspaces.focus(w3, in: space)
        core.state.apply(.windowDestroyed(w3, wasMinimized: false))
        #expect(core.state.workspaces[space]?.focused == w1)
        core.retile()
        #expect(maximized(core) == w1)
    }

    @Test("A closing window hands focus to the maximized one")
    func removeHandsFocusBack() {
        var model = Space(id: space, windows: [w1, w3, w2])
        model.maximized = w1
        model.focused = w3
        model.remove(w3)
        #expect(model.focused == w1)
    }

    @Test("A Desktop departure carries it back on return")
    func desktopReturnKeeps() {
        let core = makeCore()
        core.state.apply(.windowDestroyed(w1, wasMinimized: false))
        #expect(core.state.workspaces[space]?.maximized == nil)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w1, pid: 900_001, appName: "A")
            )
        )
        #expect(core.state.workspaces[space]?.maximized == w1)
    }

    @Test("A minimize ends it for good")
    func minimizeEnds() {
        let core = makeCore()
        core.state.apply(.windowDestroyed(w1, wasMinimized: true))
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w1, pid: 900_001, appName: "A")
            )
        )
        #expect(core.state.workspaces[space]?.maximized == nil)
    }

    @Test("A focus report onto a tiled neighbour ends it")
    func focusReportEnds() {
        let core = makeCore()
        core.handle(.windowFocused(w2))
        #expect(core.state.workspaces[space]?.maximized == nil)
        #expect(
            core.tiler.placedFrames(state: core.state)[w1]
                == core.tiler.calculatedFrames(state: core.state)[w1]
        )
    }

    @Test("Reset sizes ends it")
    func resetEnds() {
        let core = makeCore()
        core.execute("reset_layout_sizing")
        #expect(maximized(core) == nil)
    }

    @Test("A sticky window is refused")
    func stickyRefused() {
        let core = makeCore()
        core.state.setSticky(w1, .global)
        #expect(maximized(core) == nil)
        core.retile()
        #expect(!core.execute("toggle_maximized").isSuccess)
        #expect(maximized(core) == nil)
    }

    @Test("Each screen's Space keeps its own maximize")
    func everyScreenMaximizes() {
        let core = makeCore()
        let other = SpaceID("2")
        let w4 = WindowID(4)
        core.state.workspaces.assign(space, to: DisplayID(1))
        core.state.workspaces.assign(other, to: DisplayID(2))
        core.state.workspaces.activate(other)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w4, pid: 900_001, appName: "B")
            )
        )
        core.state.workspaces.focus(w4, in: other)
        #expect(core.execute("toggle_maximized").isSuccess)
        let second = core.state.workspaces[other].flatMap {
            core.state.maximizedWindow(of: $0)
        }
        #expect(second == w4)
        #expect(maximized(core) == w1)
        #expect(core.showsMaximized(on: DisplayID(1)))
        #expect(core.showsMaximized(on: DisplayID(2)))
    }

    /// Held twice over: `Space.remove`'s clear and the retile
    /// head's retire each end it, so this reds only when both go.
    @Test("Moving it to another Space ends it there and here")
    func moveToSpaceEnds() {
        let core = makeCore()
        core.execute("move_to_space", args: [.string("2")])
        #expect(core.state.workspaces[space]?.maximized == nil)
        #expect(core.state.workspaces[SpaceID("2")]?.maximized == nil)
        #expect(core.state.workspaces.space(of: w1) == SpaceID("2"))
    }

    @Test("The focused ring stands down over it")
    func ringStandsDown() {
        let core = makeCore()
        #expect(
            !core.desiredBorderSpecs().contains { $0.window == w1 }
        )
        core.execute("toggle_maximized")
        #expect(core.desiredBorderSpecs().contains { $0.window == w1 })
    }
}
