import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The case→setter mapping of a translated mouse adjustment
/// (`KiwiCore.applyResizeAdjustment`), testable without a
/// screen: a swapped case label in that switch would cross
/// the axes while `MouseResizeTests` (the translate half)
/// stayed green (#56 review).
@Suite("Mouse resize application (#56)", .serialized)
@MainActor
struct MouseResizeApplyTests {
    private let bounds = CGRect(
        x: 0,
        y: 0,
        width: 1000,
        height: 800
    )

    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return KiwiCore(configDirectory: dir)
    }

    private func space(
        _ core: KiwiCore,
        mode: String
    ) -> Space {
        core.execute(
            "set_mode",
            args: [.string("1"), .string(mode)]
        )
        return core.state.workspaces[SpaceID("1")]!
    }

    @Test("bspRatioH writes only the H ratio")
    func hAppliesToH() {
        let core = makeCore()
        let space = space(core, mode: "bsp")
        core.applyResizeAdjustment(
            .bspRatioH(0.1),
            in: space,
            bounds: bounds
        )
        let bsp = core.tiler.settings.bsp
        #expect(abs(bsp.splitRatioH - 0.6) < 1e-9)
        #expect(bsp.splitRatioV == 0.5)
    }

    @Test("bspRatioV writes only the V ratio")
    func vAppliesToV() {
        let core = makeCore()
        let space = space(core, mode: "bsp")
        core.applyResizeAdjustment(
            .bspRatioV(0.1),
            in: space,
            bounds: bounds
        )
        let bsp = core.tiler.settings.bsp
        #expect(abs(bsp.splitRatioV - 0.6) < 1e-9)
        #expect(bsp.splitRatioH == 0.5)
    }

    @Test("bspRatioH drag caps at the effective range (#383)")
    func bspRatioHDragCapped() {
        let core = makeCore()
        let space = space(core, mode: "bsp")
        // bounds 1000 wide, min 300 → effective [0.3, 0.7]: an
        // oversized drag stops at the visible cliff instead of
        // ratcheting the stored ratio to the 0.9 clamp and
        // collapsing the neighbor into the overlap pile.
        core.applyResizeAdjustment(
            .bspRatioH(0.5),
            in: space,
            bounds: bounds
        )
        #expect(abs(core.tiler.settings.bsp.splitRatioH - 0.7) < 1e-9)
    }

    @Test("bspRatioV drag caps at the effective range (#383)")
    func bspRatioVDragCapped() {
        let core = makeCore()
        let space = space(core, mode: "bsp")
        // bounds 800 tall, min 300 → effective [0.375, 0.625].
        core.applyResizeAdjustment(
            .bspRatioV(0.5),
            in: space,
            bounds: bounds
        )
        #expect(abs(core.tiler.settings.bsp.splitRatioV - 0.625) < 1e-9)
    }

    @Test("masterRatio applies onto the resolved base")
    func masterRatioApplies() {
        let core = makeCore()
        let space = space(core, mode: "stack")
        core.applyResizeAdjustment(
            .masterRatio(-0.1),
            in: space,
            bounds: bounds
        )
        let stack = core.tiler.settings.stack
        #expect(abs(stack.masterRatio - 0.5) < 1e-9)
    }

    @Test("masterRatio drag caps at the effective range (#44)")
    func masterRatioDragCapped() {
        let core = makeCore()
        let space = space(core, mode: "stack")
        // bounds 1000 wide, min 300 → effective [0.3, 0.7]:
        // an oversized drag stops at the visible cliff instead
        // of ratcheting the stored value to the 0.9 clamp.
        core.applyResizeAdjustment(
            .masterRatio(0.5),
            in: space,
            bounds: bounds
        )
        let stack = core.tiler.settings.stack
        #expect(abs(stack.masterRatio - 0.7) < 1e-9)
    }

    @Test("scrollWidth grows the slot from the given bounds")
    func scrollWidthApplies() {
        let core = makeCore()
        let space = space(core, mode: "scrolling")
        // The one case that consumes the extracted `bounds`
        // parameter: the auto slot seeds against its scroll
        // axis, then the delta lands on top in points.
        let before = core.tiler.settings.scrolling.slotSize
            .editablePoints(along: bounds.width, horizontal: true)
        core.applyResizeAdjustment(
            .scrollWidth(100),
            in: space,
            bounds: bounds
        )
        let after = core.tiler.settings.scrolling.slotSize
            .editablePoints(along: bounds.width, horizontal: true)
        #expect(abs(after - before - 100) < 0.5)
    }
}
