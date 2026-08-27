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
        return makeTestCore(configDirectory: dir)
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

    /// Session-resolved params of space "1" (#458): mouse
    /// drops on a no-override space land in the session layer.
    private func resolvedBsp(_ core: KiwiCore) -> BspParams {
        core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[SpaceID("1")]!
        )
    }

    @Test("bspRatioH writes only the H ratio")
    func hAppliesToH() {
        let core = makeCore()
        let space = space(core, mode: "bsp")
        core.applyResizeAdjustment(
            .bspRatioH(0.1),
            for: nil,
            in: space,
            bounds: bounds
        )
        let bsp = resolvedBsp(core)
        #expect(abs(bsp.splitRatioH - 0.6) < 1e-9)
        #expect(bsp.splitRatioV == 0.5)
        // The stored global is untouched (#458).
        #expect(core.tiler.settings.bsp.splitRatioH == 0.5)
    }

    @Test("bspRatioV writes only the V ratio")
    func vAppliesToV() {
        let core = makeCore()
        let space = space(core, mode: "bsp")
        core.applyResizeAdjustment(
            .bspRatioV(0.1),
            for: nil,
            in: space,
            bounds: bounds
        )
        let bsp = resolvedBsp(core)
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
            for: nil,
            in: space,
            bounds: bounds
        )
        #expect(abs(resolvedBsp(core).splitRatioH - 0.7) < 1e-9)
    }

    @Test("bspRatioV drag caps at the effective range (#383)")
    func bspRatioVDragCapped() {
        let core = makeCore()
        let space = space(core, mode: "bsp")
        // bounds 800 tall, min 300 → effective [0.375, 0.625].
        core.applyResizeAdjustment(
            .bspRatioV(0.5),
            for: nil,
            in: space,
            bounds: bounds
        )
        #expect(abs(resolvedBsp(core).splitRatioV - 0.625) < 1e-9)
    }

    @Test("masterRatio applies onto the resolved base")
    func masterRatioApplies() {
        let core = makeCore()
        let space = space(core, mode: "stack")
        core.applyResizeAdjustment(
            .masterRatio(-0.1),
            for: nil,
            in: space,
            bounds: bounds
        )
        let stack = core.tiler.settings.resolvedStack(
            for: core.state.workspaces[SpaceID("1")]!
        )
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
            for: nil,
            in: space,
            bounds: bounds
        )
        let stack = core.tiler.settings.resolvedStack(
            for: core.state.workspaces[SpaceID("1")]!
        )
        #expect(abs(stack.masterRatio - 0.7) < 1e-9)
    }

    @Test("scrollWidth adjusts the slot from the given bounds")
    func scrollWidthApplies() {
        let core = makeCore()
        let space = space(core, mode: "scrolling")
        // The one case that consumes the extracted `bounds`
        // parameter: the auto slot seeds against its scroll
        // axis, then the delta lands on top in points. The
        // delta shrinks because the seed is 95% of that axis —
        // a grow would land on the ceiling (#966) and stop
        // saying anything about the seed, which is this test's
        // subject; `scrollWidthGrowStopsAtTheAxis` below owns
        // the other end.
        let before = core.tiler.settings.scrolling.slotSize
            .editablePoints(along: bounds.width, horizontal: true)
        core.applyResizeAdjustment(
            .scrollWidth(-100),
            for: nil,
            in: space,
            bounds: bounds
        )
        let after = core.tiler.settings.resolvedScrolling(
            for: core.state.workspaces[SpaceID("1")]!
        ).slotSize
            .editablePoints(along: bounds.width, horizontal: true)
        #expect(abs(after - before + 100) < 0.5)
    }

    @Test("scrollWidth grow stops at the axis, like the verb")
    func scrollWidthGrowStopsAtTheAxis() {
        // #933's parity claim, at the ceiling end (#966): the
        // drag and the keyboard verb share one writer, so a
        // drag cannot bank slot the keyboard path refuses. The
        // seed is 950 of a 1000pt axis; +400 lands on 1000, not
        // 1350.
        let core = makeCore()
        let space = space(core, mode: "scrolling")
        core.applyResizeAdjustment(
            .scrollWidth(400),
            for: nil,
            in: space,
            bounds: bounds
        )
        let after = core.tiler.settings.resolvedScrolling(
            for: core.state.workspaces[SpaceID("1")]!
        ).slotSize
            .editablePoints(along: bounds.width, horizontal: true)
        #expect(abs(after - bounds.width) < 0.5)
    }

    @Test("trackAcross adjusts track weight")
    func trackAcrossApplies() {
        let core = makeCore()
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        core.applyResizeAdjustment(
            .trackAcross(100),
            for: WindowID(1),
            in: core.state.workspaces[space]!,
            bounds: bounds
        )
        let weights =
            core.state.workspaces[space]!.trackWeights
        #expect((weights[WindowID(1)] ?? 1) > 1)
    }

    @Test("trackAlong adjusts in-track share")
    func trackAlongApplies() {
        let core = makeCore()
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        core.applyResizeAdjustment(
            .trackAlong(100),
            for: WindowID(1),
            in: core.state.workspaces[space]!,
            bounds: bounds
        )
        let weights =
            core.state.workspaces[space]!.stackWeights
        #expect((weights[WindowID(1)] ?? 1) > 1)
    }
}
