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
        return KiwiCore(configDirectory: dir)
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

    @Test("Resize in an unoverridden space edits the global")
    func resizeHitsGlobalWhenUnoverridden() {
        let core = makeCore()
        stackSpace(core)
        let before = core.tiler.settings.stack.masterRatio
        core.execute("resize", args: [.string("x"), .number(500)])
        #expect(core.tiler.settings.stack.masterRatio != before)
        // No override was created for a space that had none.
        #expect(core.tiler.settings.stack.override.isEmpty)
    }

    @Test("Resize base is the resolved value, not the global")
    func resizeBaseIsResolved() {
        let core = makeCore()
        stackSpace(core)
        // Global 0.6, override 0.9: a downward resize off 0.9
        // lands below 0.9 (resolved base) — never off 0.6.
        core.execute(
            "stack.set_master_ratio_override",
            args: [.string("1"), .number(0.9)]
        )
        core.execute("resize", args: [.string("x"), .number(-500)])
        let value =
            core.tiler.settings.stack
            .override[SpaceID("1")]?.masterRatio ?? 0
        #expect(value > 0.6 && value < 0.9)
    }

    @Test("bsp resize also targets the space's own override")
    func bspResizeHitsOverride() {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_ratio_override",
            args: [.string("1"), .number(0.7)]
        )
        let globalBefore = core.tiler.settings.bsp.splitRatio
        core.execute("resize", args: [.string("x"), .number(500)])
        let over = core.tiler.settings.bsp.override[SpaceID("1")]
        #expect((over?.splitRatio ?? 0) > 0.7)
        #expect(core.tiler.settings.bsp.splitRatio == globalBefore)
    }
}
