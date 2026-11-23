import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The doors that record a layout undo step beside `execute`
/// (#3515): a key's fire, a drag from its first move to its drop,
/// and the App Bar reorder. A drag cancelled records nothing.
@Suite("Layout undo doors (#3515)", .serialized)
@MainActor
struct LayoutUndoDoorTests {
    private let one = SpaceID("1")

    /// Windows 1–3 of three apps in a scrolling Space 1, so the App
    /// Bar lists one item per window.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-undo-door-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.execute("set_mode", args: [.string("1"), .string("scrolling")])
        for (index, name) in ["A", "B", "C"].enumerated() {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index + 1)),
                        pid: 1,
                        appName: name
                    )
                )
            )
        }
        core.state.workspaces.focus(WindowID(1), in: one)
        // The fixture's own `set_mode` is no step under test.
        core.layoutHistory.history = LayoutUndoStacks()
        return core
    }

    private func order(_ core: KiwiCore) -> [WindowID] {
        core.state.workspaces[one]?.windows ?? []
    }

    @Test("the App Bar reorder is one step")
    func appBarReorder() {
        let core = makeCore()
        let start = order(core)
        core.moveBarItem(space: one, from: 0, to: 2)
        #expect(order(core) != start)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
    }

    /// Opens a real coordinator gesture on window 1, its first move
    /// reaching `onDragMove` through `windowMoved`.
    private func startDrag(_ core: KiwiCore) -> CGRect {
        let frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        core.drag.isMousePressed = { true }
        core.drag.windowMoved(WindowID(1), frame: frame, validated: true)
        return frame
    }

    @Test("a drag opens at its first move and records at its drop")
    func dragBracketIsWired() {
        let core = makeCore()
        let start = order(core)
        let frame = startDrag(core)
        #expect(core.layoutHistory.owners.contains(.gesture(WindowID(1))))
        // The drop's own reorder, made inside the open bracket.
        core.state.workspaces.withSpace(one) {
            $0.move(WindowID(1), to: 2)
        }
        core.drag.onDragEnd(WindowID(1), frame, frame)
        #expect(core.layoutHistory.owners.isEmpty)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
    }

    @Test("a command inside an open drag is the drag's step")
    func dragSwallowsNested() {
        let core = makeCore()
        _ = startDrag(core)
        core.execute("swap", args: [.string("right")])
        core.cancelDrag(WindowID(1))
        #expect(core.layoutHistory.owners.isEmpty)
        #expect(!core.execute("undo_layout").isSuccess)
    }

    @Test("a key's fire is one step named for its chord")
    func keyFireIsWired() {
        let core = makeCore()
        let start = order(core)
        core.keys.firePress(id: nil, label: "key x") {
            core.execute("swap", args: [.string("right")])
            core.execute("set_mode", args: [.string("stack")])
        }
        #expect(order(core) != start)
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == start)
        #expect(core.state.workspaces[one]?.mode == .scrolling)
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
    }
}
