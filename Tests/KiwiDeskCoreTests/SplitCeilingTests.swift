import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The ceiling twin of the inward post-pass (#3217, owner ruling
/// 2026-11-11): a side whose every member is capped below its
/// share yields, down to its widest ceiling, to a side that can
/// grow; the stored ratio is never written. Stack is here; BSP
/// and Grid are `SplitCeilingLayoutTests`, the share math and the
/// engine wiring `SplitCeilingShareTests`. Display and
/// `min_window_size` pinned (#531, #660).
@Suite("Split ceiling slack: Stack (#3217)")
struct SplitCeilingTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)

    @Test("A capped master yields its slack to the stack column")
    func cappedMasterYields() throws {
        let frames = SplitCeilingFixture.placed(
            .stack,
            [w1, w2, w3],
            SplitCeilingFixture.context(
                bounds: [w1: SplitCeilingFixture.ceiling(width: 500)]
            )
        )
        let master = try #require(frames[w1])
        let top = try #require(frames[w2])
        let bottom = try #require(frames[w3])
        #expect(abs(master.width - 500) < 0.01)
        #expect(abs(master.minX - 10) < 0.01)
        // The stack column starts one gap past the master and
        // ends at the usable edge: no gap between the columns.
        let gap = top.minX - master.maxX
        #expect(gap > 0 && gap < 30)
        #expect(abs(top.maxX - 1190) < 0.01)
        #expect(abs(bottom.maxX - 1190) < 0.01)
        #expect(top.minX == bottom.minX)
    }

    @Test("Without the ceiling the master keeps its full share")
    func forgottenCeilingHandsBack() throws {
        let context = SplitCeilingFixture.context(bounds: [:])
        let frames = SplitCeilingFixture.placed(
            .stack,
            [w1, w2, w3],
            context
        )
        let slots = LayoutEngine.calculate(
            mode: .stack,
            windows: [w1, w2, w3],
            context: context
        )
        #expect(frames == slots)
        #expect(try #require(frames[w1]).width > 600)
    }

    @Test("A master column with one uncapped master keeps its share")
    func oneUncappedMasterKeeps() {
        var context = SplitCeilingFixture.context(
            bounds: [w1: SplitCeilingFixture.ceiling(width: 400)]
        )
        context.stack.masterCount = 2
        context.stack.masterOrientation = .vertical
        let windows = [w1, w2, w3]
        let frames = SplitCeilingFixture.placed(.stack, windows, context)
        let slots = LayoutEngine.calculate(
            mode: .stack,
            windows: windows,
            context: context
        )
        #expect(frames[w3] == slots[w3])
        #expect(frames[w2]?.width == slots[w2]?.width)
    }

    @Test("Side-by-side masters yield only past their summed ceiling")
    func sideBySideMastersSum() throws {
        // Two masters laid along the split (the default horizontal
        // master orientation), each capped at 500: the column's
        // ceiling is 500 + gap + 500, above its ~700 pt share, so
        // nothing yields and neither master is squeezed.
        var context = SplitCeilingFixture.context(
            bounds: [
                w1: SplitCeilingFixture.ceiling(width: 500),
                w2: SplitCeilingFixture.ceiling(width: 500),
            ]
        )
        context.stack.masterCount = 2
        context.stack.masterOrientation = .horizontal
        let windows = [w1, w2, w3]
        let frames = SplitCeilingFixture.placed(.stack, windows, context)
        let slots = LayoutEngine.calculate(
            mode: .stack,
            windows: windows,
            context: context
        )
        #expect(frames == slots)
        #expect(try #require(slots[w1]).width < 500)
    }

    @Test("No stack window can grow: the gap stays")
    func noReceiverKeepsGap() {
        let context = SplitCeilingFixture.context(
            bounds: [
                w1: SplitCeilingFixture.ceiling(width: 500),
                w2: SplitCeilingFixture.ceiling(width: 300),
            ]
        )
        let frames = SplitCeilingFixture.placed(.stack, [w1, w2], context)
        let slots = LayoutEngine.calculate(
            mode: .stack,
            windows: [w1, w2],
            context: context
        )
        #expect(frames == slots)
    }

    @Test("A capped master on the right keeps the outer edge")
    func mirroredMasterKeepsOuterEdge() throws {
        var context = SplitCeilingFixture.context(
            bounds: [w1: SplitCeilingFixture.ceiling(width: 500)]
        )
        context.stack.stackPosition = .left
        let frames = SplitCeilingFixture.placed(.stack, [w1, w2], context)
        let master = try #require(frames[w1])
        let stack = try #require(frames[w2])
        #expect(abs(master.width - 500) < 0.01)
        #expect(abs(master.maxX - 1190) < 0.01)
        #expect(abs(stack.minX - 10) < 0.01)
        #expect(stack.maxX < master.minX)
        #expect(master.minX - stack.maxX < 30)
    }

    @Test("A window capped in height yields to the one below it")
    func heightCeilingInColumn() throws {
        let frames = SplitCeilingFixture.placed(
            .stack,
            [w1, w2, w3],
            SplitCeilingFixture.context(
                bounds: [w2: SplitCeilingFixture.ceiling(height: 250)]
            )
        )
        let top = try #require(frames[w2])
        let bottom = try #require(frames[w3])
        #expect(abs(top.height - 250) < 0.01)
        #expect(abs(top.minY - 10) < 0.01)
        let gap = bottom.minY - top.maxY
        #expect(gap > 0 && gap < 30)
        #expect(abs(bottom.maxY - 790) < 0.01)
    }

    @Test("A forced pass probes past the ceiling")
    func forcedPassStandsDown() {
        let context = SplitCeilingFixture.context(
            bounds: [w1: SplitCeilingFixture.ceiling(width: 500)],
            probing: true
        )
        let frames = SplitCeilingFixture.placed(.stack, [w1, w2], context)
        let slots = LayoutEngine.calculate(
            mode: .stack,
            windows: [w1, w2],
            context: context
        )
        #expect(frames == slots)
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
