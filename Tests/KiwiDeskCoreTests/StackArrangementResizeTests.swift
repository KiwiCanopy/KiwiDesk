import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Arrangement-aware stack resize (#222): the master/stack
/// ratio moves on the split axis (y for a top/bottom stack
/// zone), the per-window weights on the focused zone's own
/// axis, and an axis matching neither fails perceivably.
@Suite("Stack arrangement resize (#222)", .serialized)
@MainActor
struct StackArrangementResizeTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return KiwiCore(configDirectory: dir)
    }

    /// Stack space with three windows and the stack zone on
    /// top. `.first` placement makes the LAST created window
    /// the master, so the array is [3, 2, 1]: w3 master,
    /// w2/w1 the (horizontal) stack row.
    private func topStackSpace(_ core: KiwiCore) {
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        core.execute(
            "stack.set_stack_position",
            args: [.string("top")]
        )
        for index in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
    }

    @Test("y moves the ratio when the split is vertical")
    func splitAxisFollowsPosition() {
        let core = makeCore()
        topStackSpace(core)
        core.state.apply(.windowFocused(WindowID(3)))
        let before = core.tiler.settings.stack.masterRatio
        core.execute("resize", args: [.string("y"), .number(300)])
        #expect(core.tiler.settings.stack.masterRatio > before)
    }

    @Test("x bumps a horizontal stack row's weight")
    func weightsFollowTheZoneAxis() {
        let core = makeCore()
        topStackSpace(core)
        core.state.apply(.windowFocused(WindowID(2)))
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(200)]
        )
        #expect(response.isSuccess)
        let space = core.state.workspaces[SpaceID("1")]
        let weight = space?.stackWeights[WindowID(2)] ?? 0
        #expect(weight > 1)
    }

    @Test("The masters' cross axis has no parameter and fails")
    func crossAxisFails() {
        let core = makeCore()
        topStackSpace(core)
        // Master zone stays vertical: its weight axis is "y",
        // which the split already owns — so "x" maps to
        // nothing for a focused master.
        core.state.apply(.windowFocused(WindowID(3)))
        let before = core.tiler.settings.stack.masterRatio
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(200)]
        )
        #expect(!response.isSuccess)
        #expect(
            core.tiler.settings.stack.masterRatio == before
        )
        let space = core.state.workspaces[SpaceID("1")]
        #expect(space?.stackWeights.isEmpty != false)
    }
}
