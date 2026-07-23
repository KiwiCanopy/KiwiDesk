import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Focus-aware BSP resize direction (#122): `resize` flips the
/// delta's sign from the focused window's calculated slot, so
/// "grow" grows the focused window's region — the keyboard path
/// finally matches the mouse path's side inference.
@Suite("BSP focus-aware resize (#122)", .serialized)
@MainActor
struct BspFocusResizeTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return KiwiCore(configDirectory: dir)
    }

    /// BSP space under the ALTERNATING strategy, so the split
    /// orientation per depth is fixed regardless of the host
    /// screen's shape. BSP's `.afterFocused` placement keeps
    /// creation order: [1, 2] — w1 the left region, w2 the
    /// right; a third window splits the right region
    /// vertically — w2 top, w3 bottom. Creation focuses the
    /// last window, so tests set focus explicitly.
    private func bspSpace(_ core: KiwiCore, count: Int = 2) {
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_strategy",
            args: [.string("alternating")]
        )
        for index in 1...count {
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

    /// The session-resolved ratios of space "1" (#458): an
    /// interactive resize on a no-override space lands in the
    /// session layer, so tests read the resolved value, and the
    /// stored globals must stay untouched.
    private func resolvedBsp(_ core: KiwiCore) -> BspParams {
        core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[SpaceID("1")]!
        )
    }

    @Test("x with the left window focused raises the H ratio")
    func leftFocusGrowsLeft() {
        let core = makeCore()
        bspSpace(core)
        core.state.apply(.windowFocused(WindowID(1)))
        let before = resolvedBsp(core).splitRatioH
        core.execute("resize", args: [.string("x"), .number(200)])
        #expect(resolvedBsp(core).splitRatioH > before)
        // The global never moves for a no-override space (#458).
        #expect(core.tiler.settings.bsp.splitRatioH == before)
    }

    @Test("x with the right window focused lowers the H ratio")
    func rightFocusGrowsRight() {
        let core = makeCore()
        bspSpace(core)
        core.state.apply(.windowFocused(WindowID(2)))
        let before = resolvedBsp(core).splitRatioH
        core.execute("resize", args: [.string("x"), .number(200)])
        // +delta grows the FOCUSED window: the right region
        // widens, so the shared H ratio drops (#122).
        #expect(resolvedBsp(core).splitRatioH < before)
    }

    @Test("y with the top window focused raises the V ratio")
    func topFocusGrowsTop() {
        let core = makeCore()
        bspSpace(core, count: 3)
        // [1, 2, 3]: w1 left; the right region stacks w2 over
        // w3 (alternating → vertical at depth 1).
        core.state.apply(.windowFocused(WindowID(2)))
        let before = resolvedBsp(core).splitRatioV
        core.execute("resize", args: [.string("y"), .number(200)])
        #expect(resolvedBsp(core).splitRatioV > before)
    }

    @Test("y with the bottom window focused lowers the V ratio")
    func bottomFocusGrowsBottom() {
        let core = makeCore()
        bspSpace(core, count: 3)
        core.state.apply(.windowFocused(WindowID(3)))
        let before = resolvedBsp(core).splitRatioV
        core.execute("resize", args: [.string("y"), .number(200)])
        #expect(resolvedBsp(core).splitRatioV < before)
    }

    @Test("a huge x resize caps at the effective range (#383)")
    func resizeCapsAtEffectiveRange() {
        let core = makeCore()
        bspSpace(core)
        core.state.apply(.windowFocused(WindowID(1)))
        // The keyboard path passes the screen width as the cap
        // span; an outsized delta must stop at THAT display's
        // effective bound, not the blind 0.9 store clamp. Recompute
        // the bound from the same live span the command uses, so
        // the check is display-independent: if the cap were removed
        // the stored ratio would be 0.9 and diverge from `expected`
        // on any display narrow enough for the bound to sit below
        // 0.9 (the deterministic cap-vs-pile proof is the mouse
        // twin `MouseResizeApplyTests.bspRatioHDragCapped`).
        let span = Double(NSScreen.main?.visibleFrame.width ?? 1920)
        let minSize = Double(core.tiler.settings.minWindowSize)
        let bound = SplitDomain.effectiveRatioRange(
            available: span,
            minSize: minSize
        )!.upperBound
        let expected = min(max(bound, 0.1), 0.9)
        core.execute("resize", args: [.string("x"), .number(9000)])
        #expect(abs(resolvedBsp(core).splitRatioH - expected) < 1e-9)
    }

    @Test("x with a floating focused window resizes the float")
    func floatingFocusResizesTheFloat() {
        let core = makeCore()
        bspSpace(core)
        // A floating focused window resizes ITSELF — the
        // shared ratio must not move, in either direction.
        core.state.apply(.windowFocused(WindowID(2)))
        core.state.setFloating(WindowID(2), true)
        let before = resolvedBsp(core).splitRatioH
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(200)]
        )
        #expect(response.isSuccess)
        #expect(resolvedBsp(core).splitRatioH == before)
    }

    @Test("right focus writes the space's own override (#17)")
    func focusSignHitsOverride() {
        let core = makeCore()
        bspSpace(core)
        core.execute(
            "bsp.set_ratio_h_override",
            args: [.string("1"), .number(0.5)]
        )
        core.state.apply(.windowFocused(WindowID(2)))
        let globalBefore = core.tiler.settings.bsp.splitRatioH
        core.execute("resize", args: [.string("x"), .number(200)])
        let over =
            core.tiler.settings.bsp.override[SpaceID("1")]
        // The flipped sign still lands on the override, and
        // the shared global stays put.
        #expect((over?.splitRatioH ?? 1) < 0.5)
        #expect(
            core.tiler.settings.bsp.splitRatioH == globalBefore
        )
    }
}
