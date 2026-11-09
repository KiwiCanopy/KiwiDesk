import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
private let start = CGRect(x: 200, y: 150, width: 500, height: 400)
private let space = SpaceID("1")
private let float = WindowID(1)
private let tile = WindowID(2)
private let other = WindowID(3)
private let aside = CGRect(x: 900, y: 100, width: 300, height: 300)

/// Space 1 in `mode` with `float` floating at `start` and focused,
/// `tile` tiled beside it. The engine is off, so every write lands
/// on `Writes`.
@MainActor
private final class Writes {
    var last: [WindowID: CGRect] = [:]
}

@MainActor
private func makeCore(
    mode: String = "bsp",
    floats: [WindowID] = [float],
    writes: Writes = Writes()
) -> KiwiCore {
    let core = makeTestCore(
        configDirectory: testTemporaryDirectory.appendingPathComponent(
            "kiwi-maximize-float-\(UUID().uuidString)"
        )
    )
    core.tiler.visibleBounds = { _ in screen }
    core.execute("set_mode", args: [.string("1"), .string(mode)])
    for id in [float, tile, other] {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: 900_001,
                    appName: "App",
                    frame: id == float ? start : aside,
                    isFloating: floats.contains(id)
                )
            )
        )
    }
    core.state.apply(.windowFocused(float))
    core.tiler.animation.isEnabled = false
    core.tiler.animation.apply = { id, frame, _ in writes.last[id] = frame }
    return core
}

@MainActor
private func maximized(_ core: KiwiCore) -> WindowID? {
    core.state.workspaces[space].flatMap {
        core.state.maximizedWindow(of: $0)
    }
}

@MainActor
private func issued(_ core: KiwiCore) -> [WindowID: CGRect] {
    core.tiler.placedFrames(state: core.state)
}

/// A floating window takes Maximize (#3036): its fill is its one
/// issued frame, its old frame comes back through the one pay door,
/// and the #2448 enders end it.
@Suite("Maximize a floating window (#3036)", .serialized)
@MainActor
struct MaximizeFloatTests {
    @Test("A press fills the screen and records the return")
    func pressFills() {
        let writes = Writes()
        let core = makeCore(writes: writes)
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(maximized(core) == float)
        #expect(issued(core)[float] == screen)
        #expect(writes.last[float] == screen)
        #expect(core.state.maximizedFloatReturn[float]?.frame == start)
    }

    @Test("A second press puts it back where it was")
    func secondPressReturns() {
        let writes = Writes()
        let core = makeCore(writes: writes)
        core.execute("toggle_maximized")
        core.execute("toggle_maximized")
        #expect(maximized(core) == nil)
        #expect(issued(core)[float] == nil)
        #expect(writes.last[float] == start)
        #expect(core.state.maximizedFloatReturn[float] == nil)
    }

    @Test("Focus onto a tiled window ends it and returns the frame")
    func tileFocusEnds() {
        let writes = Writes()
        let core = makeCore(writes: writes)
        core.execute("toggle_maximized")
        core.focusWindow(tile, warp: false)
        core.retile()
        #expect(maximized(core) == nil)
        #expect(writes.last[float] == start)
    }

    @Test("Focus onto another float keeps it")
    func floatFocusKeeps() {
        let core = makeCore(floats: [float, other])
        core.execute("toggle_maximized")
        core.state.workspaces.focus(other, in: space)
        core.retile()
        #expect(maximized(core) == float)
    }

    @Test("A Floating layout Space takes it; focus never ends it")
    func floatingLayout() {
        let core = makeCore(mode: "floating", floats: [])
        #expect(core.execute("toggle_maximized").isSuccess)
        // The app takes the fill, or the learner reads a refusal.
        core.state.apply(.windowResized(float, screen))
        core.state.workspaces.focus(tile, in: space)
        core.retile()
        #expect(maximized(core) == float)
        #expect(issued(core)[float] == screen)
    }

    @Test("Tiling the window ends it with no return write")
    func tileEnds() {
        let core = makeCore()
        core.execute("toggle_maximized")
        let remembered = core.floatFrameToRemember(float)
        #expect(remembered?.frame == start)
        core.state.windows.setFloating(float, false)
        core.retile()
        #expect(maximized(core) == nil)
        #expect(core.state.maximizedFloatReturn[float] == nil)
    }

    @Test("move_floating ends it first and steps from the return")
    func moveEndsFirst() {
        let writes = Writes()
        let core = makeCore(writes: writes)
        core.execute("toggle_maximized")
        #expect(
            core.execute(
                "move_floating",
                args: [.string("x"), .number(10)]
            ).isSuccess
        )
        #expect(maximized(core) == nil)
        #expect(writes.last[float] == start)
        let moved = core.tiler.recentInstantTarget(float)
        #expect(moved == start.offsetBy(dx: 10, dy: 0))
    }

    @Test("A drag puts it back without acting on the drop")
    func dragReturns() {
        let writes = Writes()
        let core = makeCore(writes: writes)
        core.execute("toggle_maximized")
        let moved = screen.offsetBy(dx: 40, dy: 30)
        core.handleDragMove(float, start: screen, frame: moved)
        #expect(maximized(core) == nil)
        core.handleDragEnd(float, start: screen, frame: moved)
        #expect(writes.last[float] == start)
        #expect(core.state.maximizedFloatReturn[float] == nil)
    }

    @Test("An edge resize keeps the new size and forgets the return")
    func resizeKeeps() {
        let writes = Writes()
        let core = makeCore(writes: writes)
        core.execute("toggle_maximized")
        let resized = CGRect(x: 0, y: 0, width: 1200, height: 1000)
        core.handleDragMove(float, start: screen, frame: resized)
        core.handleDragEnd(float, start: screen, frame: resized)
        #expect(core.state.maximizedFloatReturn[float] == nil)
        #expect(writes.last[float] != start)
    }

    @Test("A transient overlay is refused with nothing recorded")
    func overlayRefused() {
        let core = makeCore()
        let popup = WindowID(4)
        var overlay = ManagedWindow(
            id: popup,
            pid: 900_001,
            appName: "App",
            frame: start,
            isFloating: true
        )
        overlay.isTransientOverlay = true
        core.state.apply(.windowCreated(overlay))
        core.state.apply(.windowFocused(popup))
        #expect(!core.execute("toggle_maximized").isSuccess)
        #expect(core.state.maximizedFloatReturn[popup] == nil)
        #expect(core.state.workspaces[space]?.maximized == nil)
    }

    @Test("The session snapshot records the return, not the fill")
    func snapshotRecordsReturn() {
        let core = makeCore()
        core.execute("toggle_maximized")
        core.state.apply(.windowMoved(float, screen))
        let record = core.sessionSnapshot().windows.first {
            $0.windowID == float
        }
        #expect(record?.frame == start)
    }

    @Test("An in-place stop carries the return frame")
    func inPlaceCarries() {
        let core = makeCore()
        core.execute("toggle_maximized")
        let snapshot = core.sessionSnapshot(inPlace: true)
        let record = snapshot.windows.first { $0.windowID == float }
        #expect(record?.session?.maximizedReturn == start)
        core.state.maximizedFloatReturn[float] = nil
        if let record { core.state.adoptSession(of: record) }
        #expect(core.state.maximizedFloatReturn[float]?.frame == start)
    }

    @Test("A close forgets the return; a re-key carries it")
    func lifecycle() {
        var state = StateCoordinator()
        state.maximizedFloatReturn[float] = .init(pid: 1, frame: start)
        state.rekeyFloatMemory(float, to: other)
        #expect(state.maximizedFloatReturn[other]?.frame == start)
        state.forgetFloatMemory(of: other)
        #expect(state.maximizedFloatReturn[other] == nil)
    }

    @Test("The float tier raises the maximized float first")
    func raisedLowest() {
        let core = makeCore(floats: [other, float])
        core.state.workspaces.focus(float, in: space)
        core.state.apply(.windowFocused(float))
        core.execute("toggle_maximized")
        #expect(core.floatLayerTargets().first == float)
    }

    @Test("A float on Monocle may take Maximize Height")
    func monocleHeight() {
        let core = makeCore(mode: "monocle")
        #expect(
            core.execute(
                "toggle_maximized",
                args: [.string("height")]
            ).isSuccess
        )
        #expect(maximized(core) == float)
        #expect(issued(core)[float]?.height == screen.height)
    }
}
