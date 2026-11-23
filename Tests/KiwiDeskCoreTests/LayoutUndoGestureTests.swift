import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A drag's undo step and the undo verb's refusals (#3515 review):
/// a drag abandoned, a drop after the gesture ends, two quick drags,
/// and a move back the verb refuses part-way.
@Suite("Layout undo gestures (#3515)", .serialized)
@MainActor
struct LayoutUndoGestureTests {
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Windows 1–3 tiled in Space 1, which is active; Space 2 empty.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-undo-drag-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.state.workspaces.ensureSpace(one)
        core.state.workspaces.ensureSpace(two)
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
        core.state.workspaces.focus(WindowID(1), in: one)
        return core
    }

    private func order(_ core: KiwiCore) -> [WindowID] {
        core.state.workspaces[one]?.windows ?? []
    }

    private func swap(_ core: KiwiCore, _ direction: String = "right") {
        #expect(
            core.execute("swap", args: [.string(direction)]).isSuccess
        )
    }

    @Test("an undo inside an abandoned drag leaves the next step")
    func abandonedDragLeavesNothing() {
        let core = makeCore()
        let frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        core.drag.isMousePressed = { true }
        core.drag.windowMoved(WindowID(1), frame: frame, validated: true)
        _ = core.execute("undo_layout")
        core.cancelDrag(WindowID(1))
        #expect(core.layoutHistory.pending == nil)
        let start = order(core)
        swap(core)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
    }

    @Test("a drop runs inside its drag's step after the gesture ends")
    func dropRunsInsideTheStep() {
        let core = makeCore()
        let start = order(core)
        let frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        core.drag.isMousePressed = { true }
        core.drag.windowMoved(WindowID(1), frame: frame, validated: true)
        // The drag moves the window before its drop, as a crossing
        // does, and the coordinator forgets the gesture first.
        core.state.workspaces.withSpace(one) {
            $0.move(WindowID(1), to: 2)
        }
        core.drag.cancel(WindowID(1))
        core.endLayoutGesture(WindowID(1)) {
            swap(core, "left")
            core.execute("set_mode", args: [.string("stack")])
        }
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
        #expect(core.state.workspaces[one]?.mode == .bsp)
    }

    /// Opens a real coordinator gesture on window 1.
    private func startDrag(_ core: KiwiCore) {
        let frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        core.drag.isMousePressed = { true }
        core.drag.windowMoved(WindowID(1), frame: frame, validated: true)
    }

    @Test("a refused undo of a two-window move moves neither back")
    func partialMoveRollsBack() {
        let core = makeCore()
        core.recordingLayoutStep("key m") {
            core.execute("move_to_space", args: [.string("2"), .number(1)])
            core.execute("move_to_space", args: [.string("2"), .number(2)])
        }
        let recorded = core.layoutHistory.history.candidate(.undo, of: two)
        guard case .ready = recorded else {
            Issue.record("the moves recorded no step")
            return
        }
        core.state.windows.setFullscreen(WindowID(2), true)
        #expect(!core.execute("undo_layout").isSuccess)
        #expect(core.state.workspaces.space(of: WindowID(1)) == two)
        #expect(core.state.workspaces.space(of: WindowID(2)) == two)
    }

    @Test("a refused undo inside a drag leaves the drag's step")
    func refusedUndoKeepsTheDrag() {
        let core = makeCore()
        let start = order(core)
        startDrag(core)
        #expect(!core.execute("undo_layout").isSuccess)
        core.endLayoutGesture(WindowID(1)) { swap(core) }
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
    }

    @Test("two drags inside the quiet gap are two steps")
    func dragsStayApart() {
        let core = makeCore()
        startDrag(core)
        core.endLayoutGesture(WindowID(1)) { swap(core) }
        let between = order(core)
        startDrag(core)
        core.endLayoutGesture(WindowID(1)) { swap(core, "left") }
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == between)
    }

    @Test("a drop with no open gesture opens no step of its own")
    func lateDropRecordsNothing() {
        let core = makeCore()
        core.endLayoutGesture(WindowID(1)) {
            core.state.workspaces.withSpace(one) {
                $0.move(WindowID(1), to: 2)
            }
        }
        #expect(core.layoutHistory.pending == nil)
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
    }
}
