import Foundation
import Testing

@testable import KiwiDeskCore

/// Regression guard for #17: the `resize` command must edit the
/// value the active space actually displays — its per-space
/// override when it has one, the global otherwise — never
/// silently shifting other spaces (the review's major finding).
@Suite("Per-space resize (#17)", .serialized)
@MainActor
struct PerSpaceResizeTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: dir)
    }

    // NOTE: the grow assertions below assume the host (or
    // headless-fallback 1920) screen is wide enough that the
    // #44 interactive cap sits above the tested bases — true
    // for any visible width > 1000 pt.
    private func stackSpace(_ core: KiwiCore) {
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        for index in 1...2 {
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

    @Test("Resize in an overridden space edits its override only")
    func resizeHitsOverride() {
        let core = makeCore()
        stackSpace(core)
        core.execute(
            "stack.set_master_ratio_override",
            args: [.string("1"), .number(0.7)]
        )
        let globalBefore = core.tiler.settings.stack.masterRatio
        core.execute("resize", args: [.string("x"), .number(500)])
        let over =
            core.tiler.settings.stack.override[SpaceID("1")]
        // The override moved; the shared global stayed put, so
        // other spaces are untouched.
        #expect((over?.masterRatio ?? 0) > 0.7)
        #expect(core.tiler.settings.stack.masterRatio == globalBefore)
    }

    @Test("Resize in an unoverridden space edits its session layer")
    func resizeHitsSessionWhenUnoverridden() {
        let core = makeCore()
        stackSpace(core)
        let before = core.tiler.settings.stack.masterRatio
        core.execute("resize", args: [.string("x"), .number(500)])
        // #458: the global no longer moves — every other
        // no-override space stays put — and no override is
        // silently authored either; the value lives in the
        // space's session layer.
        #expect(core.tiler.settings.stack.masterRatio == before)
        #expect(core.tiler.settings.stack.override.isEmpty)
        let space = core.state.workspaces[SpaceID("1")]
        #expect(space?.sessionRatios.masterRatio != nil)
        if let space {
            #expect(
                core.tiler.settings.resolvedStack(for: space)
                    .masterRatio != before
            )
        }
    }

    @Test("Resize base is the resolved value, not the global")
    func resizeBaseIsResolved() {
        let core = makeCore()
        stackSpace(core)
        // Override sits at the 0.9 clamp ceiling; the global stays
        // at 0.6. Resizing UP reads the resolved base (0.9) and
        // saturates at the ceiling → exactly 0.9, whatever the
        // screen width (the `resize` delta is scaled by it). Had
        // the base been the global 0.6, a step would land short of
        // 0.9. Asserting the saturated value keeps the test
        // deterministic in a headless CI.
        core.execute(
            "stack.set_master_ratio_override",
            args: [.string("1"), .number(0.9)]
        )
        core.execute("resize", args: [.string("x"), .number(10)])
        let value =
            core.tiler.settings.stack
            .override[SpaceID("1")]?.masterRatio ?? 0
        #expect(value == 0.9)
    }

    @Test("bsp resize also targets the space's own override")
    func bspResizeHitsOverride() {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_ratio_h_override",
            args: [.string("1"), .number(0.7)]
        )
        let globalBefore = core.tiler.settings.bsp.splitRatioH
        core.execute("resize", args: [.string("x"), .number(500)])
        let over = core.tiler.settings.bsp.override[SpaceID("1")]
        #expect((over?.splitRatioH ?? 0) > 0.7)
        #expect(
            core.tiler.settings.bsp.splitRatioH == globalBefore
        )
    }

    @Test("bsp resize per axis: y edits only the V ratio (#56)")
    func bspResizeAxisIndependence() {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute("resize", args: [.string("y"), .number(500)])
        // The V ratio moved (in the session layer, #458); the H
        // ratio is untouched on every layer.
        let session =
            core.state.workspaces[SpaceID("1")]?.sessionRatios
        #expect(session?.splitRatioV != nil)
        #expect(session?.splitRatioH == nil)
        #expect(core.tiler.settings.bsp.splitRatioV == 0.5)
        #expect(core.tiler.settings.bsp.splitRatioH == 0.5)
    }
}
