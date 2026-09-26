import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Re-floating a window returns it to the frame it last floated
/// at (#1675): remembered when it is tiled, consumed when it
/// floats again, and dropped on a close — session state only.
@Suite("Float frame memory (#1675)", .serialized)
@MainActor
struct FloatFrameMemoryTests {
    private let float = WindowID(2)
    private let placed = CGRect(x: 300, y: 200, width: 700, height: 500)

    /// Two windows on space 1 in bsp, w2 focused. The engine is
    /// disabled so a placement lands on the observable hook.
    private func setup(
        applied: @escaping @MainActor (WindowID, CGRect) -> Void
    ) -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-tests-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        for index in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A",
                        title: "W\(index)"
                    )
                )
            )
        }
        core.state.apply(.windowFocused(float))
        core.tiler.settings.animations.onRelayout = true
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
        return core
    }

    /// Floats w2, moves it by hand to `frame`, then tiles it.
    private func floatMoveAndTile(_ core: KiwiCore, to frame: CGRect) {
        #expect(core.execute("make_floating").isSuccess)
        core.state.apply(.windowMoved(float, frame))
        #expect(core.execute("make_tiled").isSuccess)
    }

    @Test("floating again returns to the last floating frame")
    func returnsToTheLastFrame() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        floatMoveAndTile(core, to: placed)
        #expect(core.state.floatFrames[float] == placed)
        frames = [:]
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(frames[float] == placed)
        // Consumed: the next float without one takes the default.
        #expect(core.state.floatFrames[float] == nil)
    }

    @Test("a frame on another screen falls back to the derived size")
    func otherScreenTakesTheDefault() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        let elsewhere = placed.offsetBy(dx: 3000, dy: 0)
        floatMoveAndTile(core, to: elsewhere)
        frames = [:]
        #expect(core.execute("make_floating").isSuccess)
        #expect(frames[float] != elsewhere)
        #expect(frames[float]?.width == FloatPlacement.longFloor)
    }

    @Test("a close drops the memory; a minimize keeps it")
    func closeDropsMinimizeKeeps() {
        let core = setup { _, _ in }
        floatMoveAndTile(core, to: placed)
        core.state.apply(.windowDestroyed(float, wasMinimized: true))
        #expect(core.state.floatFrames[float] == placed)
        core.state.apply(.windowDestroyed(float, wasMinimized: false))
        #expect(core.state.floatFrames[float] == nil)
    }

    @Test("an app's exit drops the memory")
    func appExitDrops() {
        let core = setup { _, _ in }
        floatMoveAndTile(core, to: placed)
        core.state.apply(.appTerminated(pid: 1))
        #expect(core.state.floatFrames[float] == nil)
    }

    @Test("keep leaves the window where it is, memory or not")
    func keepIgnoresTheMemory() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        floatMoveAndTile(core, to: placed)
        core.execute("set_float_placement", args: [.string("keep")])
        frames = [:]
        #expect(core.execute("make_floating").isSuccess)
        #expect(frames[float] == nil)
    }
}
