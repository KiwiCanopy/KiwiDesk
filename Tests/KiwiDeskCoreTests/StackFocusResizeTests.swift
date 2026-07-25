import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Focus-aware stack resize (#67): `resize("x")` moves the
/// master/stack split in the direction that grows the focused
/// window, and `resize("y")` grows the focused window's
/// vertical share of its column via the per-window weights.
@Suite("Stack focus-aware resize (#67)", .serialized)
@MainActor
struct StackFocusResizeTests {
    /// The display these fixtures resize against (#531) — the
    /// overflow cliff below is a function of its height, so pin
    /// it rather than re-deriving it from the host's screen.
    private static let display = CGRect(
        x: 0,
        y: 0,
        width: 1920,
        height: 1080
    )

    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = KiwiCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in Self.display }
        return core
    }

    /// Stack space with three windows. `.first` placement
    /// makes the LAST created window the master, so the
    /// array is [3, 2, 1]: w3 master, w2/w1 the stack column.
    private func stackSpace(_ core: KiwiCore) {
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
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

    /// Session-resolved master ratio of space "1" (#458).
    private func resolvedMaster(_ core: KiwiCore) -> Double {
        core.tiler.settings.resolvedStack(
            for: core.state.workspaces[SpaceID("1")]!
        ).masterRatio
    }

    @Test("x with the master focused grows the master ratio")
    func masterFocusGrowsMaster() {
        let core = makeCore()
        stackSpace(core)
        core.state.apply(.windowFocused(WindowID(3)))
        let before = resolvedMaster(core)
        core.execute("resize", args: [.string("x"), .number(500)])
        #expect(resolvedMaster(core) > before)
        // The global never moves for a no-override space (#458).
        #expect(core.tiler.settings.stack.masterRatio == before)
    }

    @Test("x with a stack window focused lowers the master ratio")
    func stackFocusGrowsColumn() {
        let core = makeCore()
        stackSpace(core)
        core.state.apply(.windowFocused(WindowID(1)))
        let before = resolvedMaster(core)
        core.execute("resize", args: [.string("x"), .number(500)])
        // +delta grows the FOCUSED window: the stack column
        // widens, so the master ratio drops (#67).
        #expect(resolvedMaster(core) < before)
    }

    @Test("y bumps the focused stack window's weight only")
    func verticalGrowsFocusedWeight() {
        let core = makeCore()
        stackSpace(core)
        core.state.apply(.windowFocused(WindowID(2)))
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(200)]
        )
        #expect(response.isSuccess)
        let space = core.state.workspaces[SpaceID("1")]
        let weight = space?.stackWeights[WindowID(2)] ?? 0
        #expect(weight > 1)
        // The column mate keeps its implicit even share.
        #expect(space?.stackWeights[WindowID(1)] == nil)
        // Config is untouched: weights are session state.
        #expect(core.tiler.settings.stack.masterRatio == 0.6)
    }

    @Test("y shrinks below the even share on a negative delta")
    func verticalShrinks() {
        let core = makeCore()
        stackSpace(core)
        core.state.apply(.windowFocused(WindowID(2)))
        core.execute("resize", args: [.string("y"), .number(-200)])
        let space = core.state.workspaces[SpaceID("1")]
        let weight = space?.stackWeights[WindowID(2)] ?? 1
        #expect(weight < 1)
        #expect(weight >= 0.1)  // clamped floor
    }

    @Test("y fails when the focused window is alone in its column")
    func verticalAloneFails() {
        let core = makeCore()
        stackSpace(core)
        // w3 is the sole master (master_count = 1).
        core.state.apply(.windowFocused(WindowID(3)))
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(200)]
        )
        #expect(!response.isSuccess)
        let space = core.state.workspaces[SpaceID("1")]
        #expect(space?.stackWeights.isEmpty == true)
    }

    @Test("y with no focused window fails cleanly")
    func verticalNoFocusFails() {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(200)]
        )
        #expect(!response.isSuccess)
    }

    @Test("x with a floating focused window resizes the float")
    func floatingFocusResizesTheFloat() {
        let core = makeCore()
        stackSpace(core)
        // A floating focused window resizes ITSELF — the
        // master/stack ratio must not move.
        core.state.apply(.windowFocused(WindowID(1)))
        core.state.setFloating(WindowID(1), true)
        let before = core.tiler.settings.stack.masterRatio
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(500)]
        )
        #expect(response.isSuccess)
        #expect(core.tiler.settings.stack.masterRatio == before)
    }

    @Test("y works inside a multi-window master column")
    func verticalInsideMasterColumn() {
        let core = makeCore()
        stackSpace(core)
        core.execute(
            "stack.set_master_count",
            args: [.number(2)]
        )
        // Weights live on a column lineup — pin the non-default
        // vertical orientation (side-by-side masters have no y
        // parameter; that beep is pinned elsewhere).
        core.execute(
            "stack.set_master_orientation",
            args: [.string("vertical")]
        )
        // Windows are [3, 2, 1]: w3+w2 master, w1 the stack.
        core.state.apply(.windowFocused(WindowID(3)))
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(200)]
        )
        #expect(response.isSuccess)
        let space = core.state.workspaces[SpaceID("1")]
        #expect((space?.stackWeights[WindowID(3)] ?? 0) > 1)
    }

    @Test("growing past the min-size cliff is capped, not stored")
    func growthCappedAtOverflowCliff() {
        let core = makeCore()
        stackSpace(core)
        // The cap derives from the display height, which the
        // fixture pins (#531) — a 6K host legitimately reaches
        // the 10 clamp otherwise — and from the minimum, which
        // stays at its 300pt default. Pinned, not assumed: the
        // expected weight below is span / 300 − 1.
        #expect(core.tiler.settings.minWindowSize == 300)
        let span = Double(Self.display.height)
        core.state.apply(.windowFocused(WindowID(2)))
        // Hammer Grow height far past where the column mate
        // would drop below min_window_size: the stored weight
        // must stop at the cliff instead of ratcheting to the
        // 10 clamp (review finding). Cap for a 2-window column
        // with the mate at weight 1: span/minSize − 1.
        for _ in 1...50 {
            core.execute(
                "resize",
                args: [.string("y"), .number(400)]
            )
        }
        let expected = min(max(span / 300 - 1, 1), 10)
        let space = core.state.workspaces[SpaceID("1")]
        let weight = space?.stackWeights[WindowID(2)] ?? 0
        #expect(abs(weight - expected) < 1e-9)
    }
}
