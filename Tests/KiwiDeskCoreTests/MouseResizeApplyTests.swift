import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The case→setter mapping of a translated mouse adjustment
/// (`KiwiCore.apply(_:in:bounds:)`), testable without a
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
        core.apply(.bspRatioH(0.1), in: space, bounds: bounds)
        let bsp = core.tiler.settings.bsp
        #expect(abs(bsp.splitRatioH - 0.6) < 1e-9)
        #expect(bsp.splitRatioV == 0.5)
    }

    @Test("bspRatioV writes only the V ratio")
    func vAppliesToV() {
        let core = makeCore()
        let space = space(core, mode: "bsp")
        core.apply(.bspRatioV(0.1), in: space, bounds: bounds)
        let bsp = core.tiler.settings.bsp
        #expect(abs(bsp.splitRatioV - 0.6) < 1e-9)
        #expect(bsp.splitRatioH == 0.5)
    }

    @Test("masterRatio applies onto the resolved base")
    func masterRatioApplies() {
        let core = makeCore()
        let space = space(core, mode: "stack")
        core.apply(.masterRatio(-0.1), in: space, bounds: bounds)
        let stack = core.tiler.settings.stack
        #expect(abs(stack.masterRatio - 0.5) < 1e-9)
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
        core.apply(.scrollWidth(100), in: space, bounds: bounds)
        let after = core.tiler.settings.scrolling.slotSize
            .editablePoints(along: bounds.width, horizontal: true)
        #expect(abs(after - before - 100) < 0.5)
    }
}
