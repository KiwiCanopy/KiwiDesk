import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Layout undo across a window opening or closing (#3601), through
/// the real event handler: a close or a placed open rebases the
/// stored steps; a minimize still clears them, as #3515 ruled.
@Suite("Layout undo rebase (#3601)", .serialized)
@MainActor
struct LayoutUndoRebaseTests {
    private let one = SpaceID("1")

    /// Windows 1–3 tiled in BSP Space 1, window 1 focused, each new
    /// window placed after the focused one.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-undo-rb-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.state.workspaces.ensureSpace(one)
        for id: UInt32 in 1...3 {
            core.state.apply(.windowCreated(window(id)))
        }
        core.state.workspaces.focus(WindowID(1), in: one)
        return core
    }

    private func window(_ id: UInt32) -> ManagedWindow {
        ManagedWindow(id: WindowID(id), pid: 1, appName: "A")
    }

    private func order(_ core: KiwiCore) -> [UInt32] {
        core.state.workspaces[one]?.windows.map(\.raw) ?? []
    }

    /// Swaps window 1 right: 2 1 3, focus still on 1.
    private func swap(_ core: KiwiCore) {
        #expect(core.execute("swap", args: [.string("right")]).isSuccess)
        #expect(order(core) == [2, 1, 3])
    }

    @Test("swap, close a window, undo: the swap comes back")
    func closeKeepsHistory() {
        let core = makeCore()
        swap(core)
        core.handle(.windowDestroyed(WindowID(3), wasMinimized: false))
        #expect(order(core) == [2, 1])
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == [1, 2])
        #expect(core.execute("redo_layout").isSuccess)
        #expect(order(core) == [2, 1])
    }

    @Test("a close that empties the last step drops it")
    func closeDropsEmptiedStep() {
        let core = makeCore()
        swap(core)
        core.handle(.windowDestroyed(WindowID(1), wasMinimized: false))
        #expect(order(core) == [2, 3])
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
    }

    @Test("an opened window joins older steps beside its anchor")
    func openKeepsHistory() {
        let core = makeCore()
        swap(core)
        // D (4) opens after the focused A (1): B A D C.
        core.state.workspaces.focus(WindowID(1), in: one)
        core.handle(.windowCreated(window(4)))
        #expect(order(core) == [2, 1, 4, 3])
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == [1, 4, 2, 3])
    }

    @Test("a minimize still clears the Space's history")
    func minimizeStillClears() {
        let core = makeCore()
        swap(core)
        core.handle(.windowDestroyed(WindowID(3), wasMinimized: true))
        #expect(!core.execute("undo_layout").isSuccess)
        #expect(
            core.layoutHistory.history.candidate(.undo, of: one) == .empty
        )
    }

    @Test("a change no act saw still clears after a close")
    func unrecordedChangeStillClears() {
        let core = makeCore()
        swap(core)
        // 2 3 1, unrecorded; the rebased swap would read 1 2 → 2 1,
        // which the live 2 1 matches, so only the gate refuses.
        core.state.workspaces.withSpace(one) {
            $0.move(WindowID(1), to: 2)
        }
        #expect(order(core) == [2, 3, 1])
        core.handle(.windowDestroyed(WindowID(3), wasMinimized: false))
        #expect(order(core) == [2, 1])
        #expect(!core.execute("undo_layout").isSuccess)
    }
    @Test("a track head's close hands its break on and keeps history")
    func trackHeadCloseKeepsHistory() {
        let core = makeCore()
        core.execute("set_mode", args: [.string("1"), .string("track")])
        core.layoutHistory.history = LayoutUndoStacks()
        core.state.workspaces.focus(WindowID(2), in: one)
        #expect(core.execute("swap", args: [.string("right")]).isSuccess)
        let swapped = order(core)
        #expect(swapped != [1, 2, 3])
        let head = core.state.workspaces[one]?.trackBreaks
        #expect(head?.contains(WindowID(1)) == true)
        core.handle(.windowDestroyed(WindowID(1), wasMinimized: false))
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == [2, 3])
    }

    @Test("an app's exit closes each of its windows in the history")
    func appExitKeepsHistory() {
        let core = makeCore()
        for id: UInt32 in [5, 6] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: WindowID(id), pid: 2, appName: "B")
                )
            )
        }
        core.state.workspaces.withSpace(one) {
            $0.move(WindowID(5), to: 3)
            $0.move(WindowID(6), to: 4)
        }
        core.state.workspaces.focus(WindowID(1), in: one)
        #expect(core.execute("swap", args: [.string("right")]).isSuccess)
        core.handle(.appTerminated(pid: 2))
        #expect(order(core) == [2, 1, 3])
        #expect(core.execute("undo_layout").isSuccess)
        #expect(order(core) == [1, 2, 3])
    }
}
