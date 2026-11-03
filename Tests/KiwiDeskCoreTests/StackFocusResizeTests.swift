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
        let dir =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in Self.display }
        // Pinning the display is only half of it (#531): the
        // Space Bar carves its strip out of that frame before any
        // layout sees it, so the span these tests reason about is
        // the display MINUS the bar. It cost nothing while the bar
        // defaulted to the left edge and the arithmetic here is
        // vertical — then #660 moved it to the top and the cliff
        // cap moved by exactly 32/300. Turned off rather than
        // re-pinned to an edge: this suite is about stack resize
        // maths, and a bar on any edge is one more thing for it to
        // be quietly wrong about.
        // Every bar off: the shelf reserves in every layout while
        // any can show (#1517), App Bars included.
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.tiler.settings.monocle.appBar.visibility = .hidden
        core.tiler.settings.scrolling.appBar.visibility = .hidden
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
            for: core.state.workspaces[SpaceID("1")]!,
            session: core.sessionRatios(of: SpaceID("1")),
            flip: nil
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

    @Test("growing past the min-size cliff pushes the mate into the run")
    func growthPastCliffPushesTheMate() {
        let core = makeCore()
        stackSpace(core)
        // The cliff derives from the pinned display (#531) and
        // the 300pt default minimum: the column of two cannot
        // hold w2 grown by 400 with w1 at its floor.
        #expect(core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300))
        core.tiler.settings.gapsGlobal = Gaps.uniform(10)
        core.state.apply(.windowFocused(WindowID(2)))
        // Hammer Grow height far past the cliff: the first press
        // sends w1 into the run (#2709) and w2 fills the column;
        // the rest find nothing left to grow into, and the stored
        // share never ratchets to the 10 clamp.
        for _ in 1...50 {
            core.execute(
                "resize",
                args: [.string("y"), .number(400)]
            )
        }
        let space = core.state.workspaces[SpaceID("1")]
        #expect(space?.runTails == [WindowID(2)])
        #expect(space?.runHeads.isEmpty == true)
        #expect(space?.stackWeights[WindowID(2)] == nil)
        #expect((space?.runSizes[WindowID(2)] ?? 0) > 525)
        #expect(
            core.tiler.runCovers[SpaceID("1")]?.behind[WindowID(1)]
                == WindowID(2)
        )
    }
}
