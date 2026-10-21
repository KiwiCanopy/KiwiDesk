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
/// focused.
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
    return core
}

@MainActor
private func issued(_ core: KiwiCore) -> [WindowID: CGRect] {
    core.tiler.placedFrames(state: core.state)
}

@MainActor
private func slots(_ core: KiwiCore) -> [WindowID: CGRect] {
    core.tiler.calculatedFrames(state: core.state)
}

@MainActor
private func maximized(_ core: KiwiCore) -> WindowID? {
    core.state.workspaces[space].flatMap {
        core.state.maximizedWindow(of: $0)
    }
}

/// `toggle_maximized` (#2448): the focused tiled window fills its
/// screen's visible frame with no gaps, its slot kept, until the
/// toggle, a focus onto another tiled window, or its leaving the
/// tiled set ends it.
@Suite("Maximize window (#2448)", .serialized)
@MainActor
struct MaximizeWindowTests {
    @Test("The toggle fills the visible frame; the slot is kept")
    func fillsTheScreen() {
        let core = makeCore()
        let slot = slots(core)[w1]
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(maximized(core) == w1)
        #expect(issued(core)[w1] == bounds)
        #expect(slots(core)[w1] == slot)
        #expect(issued(core)[w2] == slots(core)[w2])
    }

    @Test("A second press puts the window back in its slot")
    func secondPressRestores() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.execute("toggle_maximized")
        #expect(maximized(core) == nil)
        #expect(issued(core)[w1] == slots(core)[w1])
    }

    @Test("Focus onto another tiled window ends it, for good")
    func focusOnTiledEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.focusWindow(w2, warp: false)
        #expect(maximized(core) == nil)
        #expect(core.state.workspaces[space]?.maximized == nil)
        core.focusWindow(w1, warp: false)
        #expect(maximized(core) == nil)
        #expect(issued(core)[w1] == slots(core)[w1])
    }

    @Test("Focus onto a float of the Space keeps it")
    func focusOnFloatKeeps() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.windows.setFloating(w3, true)
        core.state.workspaces.focus(w3, in: space)
        core.state.retireEndedMaximize()
        #expect(maximized(core) == w1)
    }

    @Test("Closing the window ends it")
    func closeEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.apply(.windowDestroyed(w1, wasMinimized: false))
        #expect(maximized(core) == nil)
    }

    @Test("Floating the window ends it")
    func floatEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.windows.setFloating(w1, true)
        #expect(maximized(core) == nil)
        core.retile()
        #expect(core.state.workspaces[space]?.maximized == nil)
    }

    @Test("A swap ends it before acting")
    func swapEndsFirst() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.execute("swap", args: [.string("right")])
        #expect(maximized(core) == nil)
        #expect(issued(core)[w1] == slots(core)[w1])
    }

    @Test("Dragging the window ends it")
    func dragEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        let frame = issued(core)[w1] ?? .zero
        core.handleDragMove(w1, start: frame, frame: frame)
        #expect(maximized(core) == nil)
    }

    @Test("A float press is refused")
    func floatRefused() {
        let core = makeCore()
        core.state.windows.setFloating(w1, true)
        #expect(!core.execute("toggle_maximized").isSuccess)
        #expect(core.state.workspaces[space]?.maximized == nil)
    }

    @Test("The shelf stands down where the maximized Space shows")
    func shelfStandsDown() {
        let core = makeCore()
        let display = DisplayID(1)
        core.state.workspaces.assign(space, to: display)
        #expect(!core.showsMaximized(on: display))
        core.execute("toggle_maximized")
        #expect(core.showsMaximized(on: display))
    }

    @Test("⌃⌥M is the seeded Maximize, generation 7")
    func seedsMaximize() {
        let row = DefaultKeybindings.maximizeRow()
        #expect(row.combo == "control+option+m")
        #expect(row.lua == "KiwiDesk.toggle_maximized()")
        #expect(DefaultKeybindings.rows(ofGeneration: 7) == [row])
    }

    @Test("A rekey carries the maximized window")
    func rekeyCarries() {
        var model = Space(id: space, windows: [w1, w2])
        model.maximized = w1
        model.rekey(w1, to: w3)
        #expect(model.maximized == w3)
        // A removal keeps the id for a Desktop return; the state
        // fold and the retire end every other departure.
        model.remove(w3)
        #expect(model.maximized == w3)
    }
}
