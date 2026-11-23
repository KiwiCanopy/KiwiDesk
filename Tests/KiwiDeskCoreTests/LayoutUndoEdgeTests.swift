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
        core.drag.isMousePressed = { true }
        core.drag.windowMoved(WindowID(1), frame: frame, validated: true)
        #expect(!core.layoutHistory.owners.isEmpty)
        // The coordinator's own cancel, not `cancelDrag`'s.
        core.drag.cancel(WindowID(1))
        let start = order(core)
        swap(core)
        #expect(core.layoutHistory.owners.isEmpty)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
    }

    @Test("a glide whose end was missed leaves recording on")
    func missedGlideHeals() {
        let core = makeCore()
        core.keys.holdGlide.isGliding = true
        core.beginLayoutGlide()
        core.keys.holdGlide.isGliding = false
        let start = order(core)
        swap(core)
        #expect(core.layoutHistory.owners.isEmpty)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
    }

    private func ratio(_ core: KiwiCore) -> Double? {
        core.sessionRatios(of: one).splitRatioH
    }

    @Test("a held key's press and its glide are one step")
    func glideMergesIntoThePress() {
        let core = makeCore()
        let start = ratio(core)
        let grow: [JSONValue] = [.string("x"), .number(50)]
        // Past the quiet gap from press to the glide's end: the hold
        // merges by the press's stamp, never by its end.
        var now = Date(timeIntervalSince1970: 1000)
        core.wallClock = { now }
        core.keys.firePress(id: nil, label: "key r") {
            #expect(core.execute("resize", args: grow).isSuccess)
        }
        let pressed = ratio(core)
        #expect(pressed != start)
        // The glide, through its own wiring: frames, then the end.
        core.keys.holdGlide.isGliding = true
        now = now.addingTimeInterval(KiwiCore.layoutUndoQuietGap + 0.5)
        #expect(core.keys.holdGlide.applyGlideStep("resize", grow, 1))
        #expect(core.keys.holdGlide.applyGlideStep("resize", grow, 1))
        now = now.addingTimeInterval(3)
        core.keys.holdGlide.cancelRun()
        #expect(ratio(core) != pressed)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(ratio(core) == start)
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
    }

    @Test("a config load inside a step clears it")
    func configLoadClears() throws {
        let core = makeCore()
        // Control: the same step without the load is undoable.
        core.recordingLayoutStep("key a") { swap(core) }
        #expect(core.execute("undo_layout").isSuccess)
        // A load whose change alone would be undoable: the step
        // clears because a config load ran inside it.
        try writeStackConfig(core)
        core.recordingLayoutStep("key b") {
            swap(core)
            core.loadConfig()
            // A later, weaker answer leaves the clear standing.
            _ = core.execute("undo_layout")
        }
        #expect(core.state.workspaces[one]?.mode == .stack)
        // The clear reached the stacks: the redo "key a" left is gone.
        #expect(
            core.layoutHistory.history.candidate(.redo, of: one) == .empty
        )
        #expect(!core.execute("undo_layout").isSuccess)
    }

    private func writeStackConfig(_ core: KiwiCore) throws {
        try "KiwiDesk.set_mode(\"1\", \"stack\")\n".write(
            to: core.configDirectory.appendingPathComponent("init.lua"),
            atomically: true,
            encoding: .utf8
        )
    }

    @Test("a config load alone records nothing undoable")
    func configLoadRecordsNothing() throws {
        let core = makeCore()
        try writeStackConfig(core)
        core.loadConfig()
        #expect(core.state.workspaces[one]?.mode == .stack)
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
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
        let recorded = core.layoutHistory.history.candidate(.undo, of: two)
        guard case .ready = recorded else {
            Issue.record("the move recorded no step")
            return
        }
        core.state.windows.setFullscreen(WindowID(1), true)
        #expect(!core.execute("undo_layout").isSuccess)
        #expect(core.state.workspaces.space(of: WindowID(1)) == two)
    }

    @Test("a glide that ends inside a command records once it unwinds")
    func glideEndingInsideACommand() {
        let core = makeCore()
        let start = order(core)
        core.keys.holdGlide.isGliding = true
        core.beginLayoutGlide()
        core.recordingLayoutStep("frame") {
            swap(core)
            // A refusal cue mid-frame ends the hold here.
            core.keys.holdGlide.isGliding = false
            core.endLayoutGlide()
            core.execute("set_mode", args: [.string("stack")])
        }
        #expect(core.layoutHistory.pending == nil)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
        #expect(core.state.workspaces[one]?.mode == .bsp)
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
    }

    @Test("a new press during a hold is a step of its own")
    func pressEndsTheHold() {
        let core = makeCore()
        core.keys.holdGlide.isGliding = true
        core.beginLayoutGlide()
        swap(core)
        core.keys.firePress(id: nil, label: "key s") {
            core.execute("set_mode", args: [.string("stack")])
        }
        core.keys.holdGlide.isGliding = false
        #expect(core.execute("undo_layout").isSuccess)
        #expect(core.state.workspaces[one]?.mode == .bsp)
        let left = core.layoutHistory.history.candidate(.undo, of: one)
        guard case .ready = left else {
            Issue.record("the hold's swap was merged into the press")
            return
        }
    }
}
