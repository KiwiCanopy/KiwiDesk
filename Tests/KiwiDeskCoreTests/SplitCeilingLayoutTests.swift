import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The ceiling slack in BSP and Grid (#3217, owner ruling
/// 2026-11-11): a BSP side yields only when every window under it
/// is capped, a Grid column or row only when every window in it
/// is. Stack is `SplitCeilingTests`. Display and
/// `min_window_size` pinned (#531, #660).
@Suite("Split ceiling slack: BSP and Grid (#3217)")
struct SplitCeilingLayoutTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)
    private let w4 = WindowID(4)

    @Test("A capped BSP side yields to its sibling")
    func bspSideYields() throws {
        let frames = SplitCeilingFixture.placed(
            .bsp,
            [w1, w2],
            SplitCeilingFixture.context(
                bounds: [w1: SplitCeilingFixture.ceiling(width: 400)]
            )
        )
        let left = try #require(frames[w1])
        let right = try #require(frames[w2])
        #expect(abs(left.width - 400) < 0.01)
        #expect(abs(left.minX - 10) < 0.01)
        let gap = right.minX - left.maxX
        #expect(gap > 0 && gap < 30)
        #expect(abs(right.maxX - 1190) < 0.01)
    }

    @Test("A BSP side with one uncapped window keeps its share")
    func bspSideWithUncappedKeeps() {
        let windows = [w1, w2, w3]
        let context = SplitCeilingFixture.context(
            bounds: [w2: SplitCeilingFixture.ceiling(width: 300)]
        )
        let frames = SplitCeilingFixture.placed(.bsp, windows, context)
        let slots = LayoutEngine.calculate(
            mode: .bsp,
            windows: windows,
            context: context
        )
        #expect(frames[w1] == slots[w1])
        #expect(frames[w2]?.width == slots[w2]?.width)
        #expect(frames[w3]?.width == slots[w3]?.width)
    }

    @Test("A BSP side whose every window is capped yields")
    func bspSideAllCappedYields() throws {
        let frames = SplitCeilingFixture.placed(
            .bsp,
            [w1, w2, w3],
            SplitCeilingFixture.context(
                bounds: [
                    w2: SplitCeilingFixture.ceiling(width: 300),
                    w3: SplitCeilingFixture.ceiling(width: 300),
                ]
            )
        )
        let left = try #require(frames[w1])
        let top = try #require(frames[w2])
        let bottom = try #require(frames[w3])
        // The right side stacks w2 over w3, so its ceiling is the
        // wider of the two: 300.
        #expect(abs(top.width - 300) < 0.01)
        #expect(abs(bottom.width - 300) < 0.01)
        #expect(abs(top.maxX - 1190) < 0.01)
        #expect(abs(left.minX - 10) < 0.01)
        let gap = top.minX - left.maxX
        #expect(gap > 0 && gap < 30)
    }

    @Test("A Grid column whose every window is capped yields")
    func gridColumnYields() throws {
        // 2 × 2, row by row: w1 and w3 hold the first column.
        let frames = SplitCeilingFixture.placed(
            .grid,
            [w1, w2, w3, w4],
            SplitCeilingFixture.context(
                bounds: [
                    w1: SplitCeilingFixture.ceiling(width: 400),
                    w3: SplitCeilingFixture.ceiling(width: 350),
                ]
            )
        )
        let first = try #require(frames[w1])
        let below = try #require(frames[w3])
        let second = try #require(frames[w2])
        #expect(abs(first.width - 400) < 0.01)
        #expect(abs(below.width - 400) < 0.01)
        let gap = second.minX - first.maxX
        #expect(gap > 0 && gap < 30)
        #expect(abs(second.maxX - 1190) < 0.01)
        #expect(frames[w4]?.minX == second.minX)
    }

    @Test("A Grid column with one uncapped window keeps its width")
    func gridColumnWithUncappedKeeps() {
        let windows = [w1, w2, w3, w4]
        let context = SplitCeilingFixture.context(
            bounds: [w1: SplitCeilingFixture.ceiling(width: 400)]
        )
        let frames = SplitCeilingFixture.placed(.grid, windows, context)
        let slots = LayoutEngine.calculate(
            mode: .grid,
            windows: windows,
            context: context
        )
        #expect(frames == slots)
    }

    @Test("A Grid row whose every window is capped yields")
    func gridRowYields() throws {
        let frames = SplitCeilingFixture.placed(
            .grid,
            [w1, w2, w3, w4],
            SplitCeilingFixture.context(
                bounds: [
                    w1: SplitCeilingFixture.ceiling(height: 250),
                    w2: SplitCeilingFixture.ceiling(height: 250),
                ]
            )
        )
        let top = try #require(frames[w1])
        let below = try #require(frames[w3])
        #expect(abs(top.height - 250) < 0.01)
        #expect(frames[w2]?.height == top.height)
        let gap = below.minY - top.maxY
        #expect(gap > 0 && gap < 30)
        #expect(abs(below.maxY - 790) < 0.01)
    }
}

/// This file's ceiling fixture; the sibling suites keep their own
/// copy (tests.md: per-file helpers).
private enum SplitCeilingFixture {
    /// A corroborated ceiling: two distinct asks answered with
    /// one smaller span.
    static func ceiling(
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) -> EffectiveSizeBound {
        func axis(_ size: CGFloat?) -> [EffectiveSizeBound.Axis] {
            guard let size else { return [] }
            return [
                .init(asked: size + 200, answered: size),
                .init(asked: size + 250, answered: size),
            ]
        }
        return EffectiveSizeBound(width: axis(width), height: axis(height))
    }

    static func context(
        bounds: [WindowID: EffectiveSizeBound],
        probing: Bool = false
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 800),
            minWindowSize: 200,
            sizeBounds: bounds
        )
        context.probesBeyondBounds = probing
        return context
    }

    /// The frames the retile issues: the slots through the one
    /// post-pass door.
    static func placed(
        _ mode: LayoutMode,
        _ windows: [WindowID],
        _ context: LayoutContext
    ) -> [WindowID: CGRect] {
        SplitOverflow.placed(
            mode: mode,
            windows: windows,
            frames: LayoutEngine.calculate(
                mode: mode,
                windows: windows,
                context: context
            ),
            context: context
        )
    }
}
