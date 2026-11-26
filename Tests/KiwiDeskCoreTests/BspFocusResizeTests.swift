import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Focus-aware BSP resize direction (#122, #3672): `resize` moves
/// the split the focused window's edge sits on, so "grow" grows the
/// focused window — its own split's ratio rises, a split it sits
/// behind falls.
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
        let dir =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in Self.display }
        // No Space Bar, so the pinned rect IS the resize span: the
        // span is the layout region since #537, and the default
        // bar's 32pt strip would turn the cap literal below into a
        // re-derivation of two formulas at once. That the strip is
        // reserved has its own suite
        // (`LayoutBoundsResizeSeamTests`); this one is about the
        // #383 cap.
        core.execute(
            "space_bar.set_visibility",
            args: [.string("hidden")]
        )
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
            for: core.state.workspaces[SpaceID("1")]!,
            session: core.sessionRatios(of: SpaceID("1"))
        )
    }

    /// `owner`'s split ratio on the axis `sideBySide` names: its own
    /// (#3672), else the shared one.
    private func split(
        _ core: KiwiCore,
        _ owner: UInt32,
        sideBySide: Bool = true
    ) -> Double {
        core.sessionRatios(of: SpaceID("1")).bspSplits?.ratio(
            of: WindowID(owner),
            sideBySide: sideBySide
        )
            ?? (sideBySide
                ? resolvedBsp(core).splitRatioH
                : resolvedBsp(core).splitRatioV)
    }

    @Test("x with the left window focused raises the H ratio")
    func leftFocusGrowsLeft() {
        let core = makeCore()
        bspSpace(core)
        core.state.apply(.windowFocused(WindowID(1)))
        let before = split(core, 1)
        core.execute("resize", args: [.string("x"), .number(200)])
        #expect(split(core, 1) > before)
        // The global never moves for a no-override space (#458).
        #expect(core.tiler.settings.bsp.splitRatioH == before)
    }

    @Test("x with the right window focused lowers the H ratio")
    func rightFocusGrowsRight() {
        let core = makeCore()
        bspSpace(core)
        core.state.apply(.windowFocused(WindowID(2)))
        let before = split(core, 1)
        core.execute("resize", args: [.string("x"), .number(200)])
        // +delta grows the FOCUSED window: it sits behind w1's
        // split, so that split's ratio drops.
        #expect(split(core, 1) < before)
    }

    @Test("y with the top window focused raises the V ratio")
    func topFocusGrowsTop() {
        let core = makeCore()
        bspSpace(core, count: 3)
        // [1, 2, 3]: w1 left; the right region stacks w2 over
        // w3 (alternating → vertical at depth 1).
        core.state.apply(.windowFocused(WindowID(2)))
        let before = split(core, 2, sideBySide: false)
        core.execute("resize", args: [.string("y"), .number(200)])
        #expect(split(core, 2, sideBySide: false) > before)
    }

    @Test("y with the bottom window focused lowers the V ratio")
    func bottomFocusGrowsBottom() {
        let core = makeCore()
        bspSpace(core, count: 3)
        core.state.apply(.windowFocused(WindowID(3)))
        let before = split(core, 2, sideBySide: false)
        core.execute("resize", args: [.string("y"), .number(200)])
        #expect(split(core, 2, sideBySide: false) < before)
    }

    @Test("a huge x resize caps at the effective range (#383)")
    func resizeCapsAtEffectiveRange() {
        let core = makeCore()
        bspSpace(core)
        core.state.apply(.windowFocused(WindowID(1)))
        // An outsized delta must stop where w2 keeps its floor, not
        // at the blind 0.9 store clamp: on 1600pt against the 300pt
        // default minimum, 0.9 would leave w2 under it. (The mouse
        // twin is `RunPushCommandTests` ▸ `dragStopsAtTheRestFloor`.)
        #expect(core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300))
        core.execute("resize", args: [.string("x"), .number(9000)])
        core.retile()
        let w2 = core.tiler.calculatedFrames(state: core.state)[
            WindowID(2)
        ]
        #expect(abs((w2?.width ?? 0) - 300) < 1)
        #expect(split(core, 1) < 0.9)
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

    @Test("right focus moves the space's own value (#17)")
    func focusSignMovesTheResolvedValue() {
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
        // The flipped sign lands on the space's resolved value
        // (the session layer, #764), the authored override keeps
        // its number and the shared global stays put.
        #expect(over?.splitRatioH == 0.5)
        #expect(split(core, 1) < 0.5)
        #expect(
            core.tiler.settings.bsp.splitRatioH == globalBefore
        )
    }
}
