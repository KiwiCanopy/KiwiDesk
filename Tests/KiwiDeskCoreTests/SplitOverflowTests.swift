import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The inward overflow post-pass (#934, owner ruling 2026-08-31):
/// a bsp or stack slot under a learned floor is emitted at the
/// floor, inside the layout region, never past the screen edge.
/// The heal's math is `SplitFloorHealTests`; the placement over a
/// real core is `SplitFloorCueTests`. Every context pins its
/// display and `min_window_size` (#531, #660).
@Suite("Split inward overflow (#934)")
struct SplitOverflowTests {

    /// A corroborated floor: two distinct asks answered with `size`.
    private func floor(_ size: CGFloat) -> EffectiveSizeBound {
        EffectiveSizeBound(
            width: [
                .init(asked: size - 200, answered: size),
                .init(asked: size - 250, answered: size),
            ]
        )
    }

    private func heightFloor(_ size: CGFloat) -> EffectiveSizeBound {
        EffectiveSizeBound(
            height: [
                .init(asked: size - 65, answered: size),
                .init(asked: size - 110, answered: size),
            ]
        )
    }

    /// The frames the retile issues for `mode`: the layout's
    /// slots through the one post-pass.
    private func placed(
        _ mode: LayoutMode,
        _ windows: [WindowID],
        _ context: LayoutContext
    ) -> [WindowID: CGRect] {
        SplitOverflow.placed(
            mode: mode,
            frames: LayoutEngine.calculate(
                mode: mode,
                windows: windows,
                context: context
            ),
            context: context
        )
    }

    private func context(
        bounds: [WindowID: EffectiveSizeBound],
        probing: Bool = false
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 800),
            minWindowSize: 300,
            sizeBounds: bounds
        )
        context.probesBeyondBounds = probing
        return context
    }

    @Test("A bsp slot under a learned floor lands at the floor, inside")
    func bspFloorLandsInward() throws {
        let w1 = WindowID(1)
        let w2 = WindowID(2)
        let frames = placed(
            .bsp,
            [w1, w2],
            context(bounds: [w2: floor(700)])
        )
        let right = try #require(frames[w2])
        // The 585 pt right slot widens to 700 and pulls back so
        // its trailing edge stays at the usable edge (1190).
        #expect(right.width == 700)
        #expect(abs(right.maxX - 1190) < 0.01)
        #expect(right.minX >= 10)
        #expect(try #require(frames[w1]).width < 600)
    }

    @Test("A stacked bsp slot under a height floor lands inward too")
    func bspHeightFloorLandsInward() throws {
        let ids = (1...3).map { WindowID(UInt32($0)) }
        let frames = placed(
            .bsp,
            ids,
            context(bounds: [ids[2]: heightFloor(450)])
        )
        let bottom = try #require(frames[ids[2]])
        #expect(bottom.height == 450)
        #expect(abs(bottom.maxY - 790) < 0.01)
    }

    @Test("A stack zone under a learned floor lands inward")
    func stackFloorLandsInward() throws {
        let w1 = WindowID(1)
        let w2 = WindowID(2)
        let frames = placed(
            .stack,
            [w1, w2],
            context(bounds: [w2: floor(700)])
        )
        let stack = try #require(frames[w2])
        #expect(stack.width == 700)
        #expect(abs(stack.maxX - 1190) < 0.01)
    }

    @Test("A floor wider than the region keeps its leading edge")
    func floorWiderThanTheRegionKeepsTheLead() throws {
        let w1 = WindowID(1)
        let w2 = WindowID(2)
        let frames = placed(
            .bsp,
            [w1, w2],
            context(bounds: [w2: floor(1300)])
        )
        let right = try #require(frames[w2])
        #expect(right.width == 1300)
        #expect(right.minX == 10)
    }

    @Test("A learned ceiling is left to the app")
    func ceilingsAreLeftAlone() throws {
        let w1 = WindowID(1)
        let ceiling = EffectiveSizeBound(
            width: [
                .init(asked: 800, answered: 600),
                .init(asked: 900, answered: 600),
            ]
        )
        let frames = placed(
            .bsp,
            [w1],
            context(bounds: [w1: ceiling])
        )
        #expect(try #require(frames[w1]).width == 1180)
    }

    @Test("A forced pass probes past the floor")
    func forcedPassProbesPastTheFloor() throws {
        let w1 = WindowID(1)
        let w2 = WindowID(2)
        let frames = placed(
            .bsp,
            [w1, w2],
            context(bounds: [w2: floor(700)], probing: true)
        )
        #expect(try #require(frames[w2]).width < 600)
    }

    @Test("Grid keeps the slot")
    func gridKeepsTheSlot() throws {
        let w1 = WindowID(1)
        let w2 = WindowID(2)
        let frames = placed(
            .grid,
            [w1, w2],
            context(bounds: [w2: floor(700)])
        )
        #expect(try #require(frames[w2]).width < 700)
    }

    @Test("The origin pulls back to the trailing edge, never past the lead")
    func inwardOrigin() {
        #expect(
            SplitOverflow.inwardOrigin(
                605,
                extent: 700,
                lead: 10,
                trail: 1190
            ) == 490
        )
        #expect(
            SplitOverflow.inwardOrigin(
                10,
                extent: 1300,
                lead: 10,
                trail: 1190
            ) == 10
        )
        #expect(
            SplitOverflow.inwardOrigin(
                10,
                extent: 585,
                lead: 10,
                trail: 1190
            ) == 10
        )
    }
}
