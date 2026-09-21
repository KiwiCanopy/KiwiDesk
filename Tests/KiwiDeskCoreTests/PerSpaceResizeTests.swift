import Foundation
import Testing

@testable import KiwiDeskCore

/// Regression guard for #17: the `resize` command must move the
/// value the active space actually displays — never the global,
/// which would silently shift other spaces (the review's major
/// finding) — and since #764 never the authored override either:
/// the write lands in the Space's session layer, which outranks
/// both.
@Suite("Per-space resize (#17)", .serialized)
@MainActor
struct PerSpaceResizeTests {
    /// The display these ratio clamps resize against (#531).
    /// Pin it so a narrow headless runner cannot lower the cap.
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
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in Self.display }
        #expect(core.tiler.settings.minWindowSize == 300)
        return core
    }

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

    @Test("Resize in an overridden space moves what it displays")
    func resizeMovesTheResolvedValue() {
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
        // The resolved value moved off the authored 0.7 — in the
        // session layer (#764) — while the override keeps the
        // authored number and the shared global stays put, so
        // other spaces are untouched.
        #expect(over?.masterRatio == 0.7)
        let space = core.state.workspaces[SpaceID("1")]
        if let space {
            #expect(
                core.tiler.settings.resolvedStack(for: space)
                    .masterRatio > 0.7
            )
        }
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
        let space = core.state.workspaces[SpaceID("1")]
        let value = space.map {
            core.tiler.settings.resolvedStack(for: $0).masterRatio
        }
        #expect(value == 0.9)
    }

    @Test("bsp resize moves what the space displays, not its override")
    func bspResizeMovesTheResolvedValue() {
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
        #expect(over?.splitRatioH == 0.7)
        if let space = core.state.workspaces[SpaceID("1")] {
            #expect(
                core.tiler.settings.resolvedBsp(for: space)
                    .splitRatioH > 0.7
            )
        }
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
