import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The ways a layout undo step could be lost, kept or refused
/// wrongly (#3515 review): an undo outside a bracket, a drag that
/// ends without a drop, a held key's glide, a config load, a key
/// change inside a step, and a move back that the verb refuses.
@Suite("Layout undo edges (#3515)", .serialized)
@MainActor
struct LayoutUndoEdgeTests {
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Windows 1–3 tiled in Space 1, which is active; Space 2 empty.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-undo-edge-\(UUID().uuidString)")
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

    @Test("an undo outside any bracket leaves the next step recorded")
    func bareUndoKeepsRecording() {
        let core = makeCore()
        #expect(!core.execute("undo_layout").isSuccess)
        let start = order(core)
        swap(core)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
    }

    @Test("a drag the coordinator cancels leaves recording on")
    func cancelledDragHeals() {
        let core = makeCore()
        let frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        core.drag.onDragMove(WindowID(1), frame, frame)
        #expect(!core.layoutHistory.gestures.isEmpty)
        core.drag.cancel(WindowID(1))
        #expect(core.layoutHistory.gestures.isEmpty)
        let start = order(core)
        swap(core)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
    }

    @Test("a held key's press and glide are one step")
    func glideMergesIntoThePress() {
        let core = makeCore()
        let mode = { core.state.workspaces[one]?.mode }
        core.keys.firePress(id: nil, label: "key r") {
            core.execute("set_mode", args: [.string("stack")])
        }
        core.keys.holdGlide.isGliding = true
        core.beginLayoutGlide()
        core.execute("set_mode", args: [.string("grid")])
        core.execute("set_mode", args: [.string("track")])
        core.keys.holdGlide.isGliding = false
        core.endLayoutGlide()
        #expect(mode() == .track)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(mode() == .bsp)
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
    }

    @Test("a config load clears, even inside a command's step")
    func configLoadClears() {
        let core = makeCore()
        core.recordingLayoutStep("config", undoable: false) {
            swap(core)
        }
        #expect(!core.execute("undo_layout").isSuccess)
        core.recordingLayoutStep("reload_config") {
            swap(core, "left")
            core.recordingLayoutStep("config", undoable: false) {}
        }
        #expect(!core.execute("undo_layout").isSuccess)
    }

    @Test("a step across a sizing key change is not undoable")
    func keyChangeIsNotUndoable() {
        let space = Space(id: one, windows: [WindowID(1)])
        func arrangement(_ desktop: UInt64?) -> SpaceArrangement {
            SpaceArrangement(
                space,
                sizing: SpaceSizing(
                    key: SessionSizingKey(
                        desktop: desktop.map { SkyLight.SpaceID($0) },
                        arrangement: nil
                    ),
                    ratios: SessionRatios()
                )
            )
        }
        #expect(
            KiwiCore.isUndoable([one: arrangement(1)], [one: arrangement(1)])
        )
        #expect(
            !KiwiCore.isUndoable([one: arrangement(1)], [one: arrangement(2)])
        )
    }

    @Test("a move back the verb refuses refuses the undo")
    func refusedMoveRefuses() {
        let core = makeCore()
        #expect(
            core.execute(
                "move_to_space",
                args: [.string("2"), .number(1)]
            ).isSuccess
        )
        core.state.windows.setFullscreen(WindowID(1), true)
        #expect(!core.execute("undo_layout").isSuccess)
        #expect(core.state.workspaces.space(of: WindowID(1)) == two)
    }
}
