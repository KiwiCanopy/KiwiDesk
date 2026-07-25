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
    /// The display these fixtures resize against (#531) — the
    /// cap span below is read straight off its width, so the
    /// expected ratio is a literal instead of a re-derivation of
    /// whatever screen the host has.
    private static let display = CGRect(
        x: 0,
        y: 0,
        width: 1600,
        height: 1000
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
        // The keyboard path passes the display width as the cap
        // span; an outsized delta must stop at THAT display's
        // effective bound, not the blind 0.9 store clamp. With the
        // display pinned (#531) the bound is a literal rather than
        // a re-derivation of the formula under test: 1600pt wide
        // against the 300pt default minimum leaves
        // (1600 − 300) / 1600 = 0.8125, below the 0.9 clamp — so a
        // removed cap would store 0.9 and fail here. (The mouse
        // twin is `MouseResizeApplyTests.bspRatioHDragCapped`.)
        #expect(core.tiler.settings.minWindowSize == 300)
        core.execute("resize", args: [.string("x"), .number(9000)])
        #expect(
            abs(resolvedBsp(core).splitRatioH - 0.8125) < 1e-9
        )
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
