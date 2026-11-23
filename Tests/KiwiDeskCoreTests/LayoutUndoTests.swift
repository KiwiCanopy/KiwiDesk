import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `undo_layout` and `redo_layout` through the real dispatch
/// (#3515): a command is one step, a move between Spaces is one
/// step on both, and a change no bracket saw refuses the next undo.
@Suite("Layout undo (#3515)", .serialized)
@MainActor
struct LayoutUndoTests {
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Windows 1–3 tiled in Space 1, which is active; Space 2 empty.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-undo-\(UUID().uuidString)")
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

    private func order(_ id: SpaceID, _ core: KiwiCore) -> [WindowID] {
        core.state.workspaces[id]?.windows ?? []
    }

    @Test("a swap undoes and redoes")
    func swapRoundTrips() {
        let core = makeCore()
        let start = order(one, core)
        #expect(core.execute("swap", args: [.string("right")]).isSuccess)
        let swapped = order(one, core)
        #expect(swapped != start)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(one, core) == start)
        #expect(core.execute("redo_layout").isSuccess)
        #expect(order(one, core) == swapped)
    }

    @Test("a layout change undoes with its sizes")
    func modeRoundTrips() {
        let core = makeCore()
        core.withSessionRatios(of: one) { $0.splitRatioH = 0.7 }
        #expect(core.execute("set_mode", args: [.string("stack")]).isSuccess)
        #expect(core.sessionRatios(of: one).splitRatioH == nil)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(core.state.workspaces[one]?.mode == .bsp)
        #expect(core.sessionRatios(of: one).splitRatioH == 0.7)
    }

    @Test("a move between Spaces undoes from either Space")
    func moveIsLinked() {
        for undoFrom in [one, two] {
            let core = makeCore()
            let start = order(one, core)
            #expect(
                core.execute(
                    "move_to_space",
                    args: [.string("2"), .number(1)]
                ).isSuccess
            )
            #expect(order(two, core) == [WindowID(1)])
            core.state.workspaces.activate(undoFrom)
            #expect(core.execute("undo_layout").isSuccess)
            #expect(order(one, core) == start)
            #expect(order(two, core).isEmpty)
        }
    }

    @Test("a change no bracket saw refuses and clears")
    func unrecordedChangeRefuses() {
        let core = makeCore()
        #expect(core.execute("swap", args: [.string("right")]).isSuccess)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(9), pid: 1, appName: "A")
            )
        )
        #expect(!core.execute("undo_layout").isSuccess)
        #expect(!core.execute("undo_layout").isSuccess)
        #expect(core.layoutHistory.history.candidate(.undo, of: one) == .empty)
    }

    @Test("nothing to undo or redo refuses")
    func emptyRefuses() {
        let core = makeCore()
        #expect(!core.execute("undo_layout").isSuccess)
        #expect(!core.execute("redo_layout").isSuccess)
    }

    @Test("a new change clears the redo")
    func newChangeClearsRedo() {
        let core = makeCore()
        #expect(core.execute("swap", args: [.string("right")]).isSuccess)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(core.execute("set_mode", args: [.string("stack")]).isSuccess)
        #expect(!core.execute("redo_layout").isSuccess)
    }

    @Test("one key's body is one step, and undo inside it records none")
    func bracketCoalesces() {
        let core = makeCore()
        let start = order(one, core)
        core.recordingLayoutStep("key a") {
            core.execute("swap", args: [.string("right")])
            core.execute("set_mode", args: [.string("stack")])
        }
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(one, core) == start)
        #expect(core.state.workspaces[one]?.mode == .bsp)
        // One step, not one per command inside it.
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
        core.recordingLayoutStep("key z") {
            core.execute("redo_layout")
        }
        #expect(core.state.workspaces[one]?.mode == .stack)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(core.state.workspaces[one]?.mode == .bsp)
        // The redo inside "key z" recorded no step of its own.
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
    }

    @Test("a step that changes members, or three Spaces, only clears")
    func shapesThatClear() {
        let core = makeCore()
        let three = SpaceID("3")
        core.state.workspaces.ensureSpace(three)
        #expect(core.execute("swap", args: [.string("right")]).isSuccess)
        core.recordingLayoutStep("open") {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: WindowID(7), pid: 1, appName: "A")
                )
            )
        }
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
        #expect(core.execute("swap", args: [.string("left")]).isSuccess)
        core.recordingLayoutStep("spread") {
            core.state.workspaces.withSpace(one) {
                $0.move(WindowID(1), to: 2)
            }
            core.state.workspaces.add(WindowID(2), to: two)
            core.state.workspaces.add(WindowID(3), to: three)
        }
        for space in [one, two, three] {
            #expect(
                core.layoutHistory.history.candidate(.undo, of: space)
                    == .empty
            )
        }
    }
}
