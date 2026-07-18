import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)

/// #44: an extreme `master_ratio` is clamped to the widest
/// value that keeps BOTH zones ≥ `min_window_size`; the
/// cascade stays reserved for regions genuinely too narrow
/// for two min-size zones at any ratio.
@Suite("Stack master_ratio clamp (#44)")
struct StackRatioClampTests {
    let layout = StackLayout()

    private func makeContext(
        ratio: Double,
        width: CGFloat = 1920
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: width, height: 1080),
            gaps: .uniform(10)
        )
        context.stack.masterRatio = ratio
        return context
    }

    @Test("An extreme ratio clamps: side zone pinned to min")
    func extremeRatioClamps() throws {
        // usable 1900, available 1890; 0.9 would leave the
        // stack 189 pt < 300 — the old code cascaded here.
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext(ratio: 0.9)
        )
        let master = try #require(frames[w1])
        let stack = try #require(frames[w2])
        // Proper split, no cascade: side by side, stack zone
        // pinned to exactly min_window_size (300).
        #expect(abs(stack.width - 300) < 0.01)
        #expect(abs(master.width - 1590) < 0.01)
        #expect(abs(stack.minX - master.maxX - 10) < 0.01)
    }

    @Test("A tiny ratio clamps the master up to min")
    func tinyRatioClamps() throws {
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext(ratio: 0.05)
        )
        let master = try #require(frames[w1])
        let stack = try #require(frames[w2])
        #expect(abs(master.width - 300) < 0.01)
        #expect(abs(stack.width - 1590) < 0.01)
    }

    @Test("A truly-too-narrow region still cascades")
    func genuineCascade() throws {
        // usable 480, available 470 < 2·300: no ratio can fit
        // two min-size zones — the genuine last resort.
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext(ratio: 0.6, width: 500)
        )
        let a = try #require(frames[w1])
        let b = try #require(frames[w2])
        #expect(a.minX == b.minX)
        #expect(b.minY - a.minY == OverlapStack.offset)
    }

    @Test("An in-range ratio is untouched by the clamp")
    func inRangeRatioUntouched() throws {
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext(ratio: 0.6)
        )
        let master = try #require(frames[w1])
        #expect(abs(master.width - 1890 * 0.6) < 0.01)
    }

    @Test("Exactly two min-size zones split, never cascade")
    func exactBoundarySplits() throws {
        // width 630 → usable 610, available 600 == 2·300: the
        // strict < keeps this on the split side, ratio forced
        // to 0.5 so both zones are exactly min.
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext(ratio: 0.9, width: 630)
        )
        let master = try #require(frames[w1])
        let stack = try #require(frames[w2])
        #expect(abs(master.width - 300) < 0.01)
        #expect(abs(stack.width - 300) < 0.01)
        #expect(stack.minX > master.maxX)
    }

    @Test("effectiveRatioRange edges: too narrow, no minimum")
    func rangeEdges() {
        #expect(
            SplitDomain.effectiveRatioRange(
                available: 599,
                minSize: 300
            ) == nil
        )
        #expect(
            SplitDomain.effectiveRatioRange(
                available: 1000,
                minSize: 0
            ) == 0...1
        )
        // Degenerate region cascades even with no minimum.
        #expect(
            SplitDomain.effectiveRatioRange(
                available: -20,
                minSize: 0
            ) == nil
        )
    }

    @Test("cappedRatioWrite stops at the range, never reverses")
    func cappedWrite() {
        // available 1000, min 300 → range [0.3, 0.7].
        let capped = SplitDomain.cappedRatioWrite(
            0.95,
            base: 0.6,
            available: 1000,
            minSize: 300
        )
        #expect(abs(capped - 0.7) < 1e-9)
        // A base already past the bound is not pushed back on
        // a grow — it just stops moving.
        let held = SplitDomain.cappedRatioWrite(
            0.92,
            base: 0.9,
            available: 1000,
            minSize: 300
        )
        #expect(abs(held - 0.9) < 1e-9)
        // Shrinking from out-of-range re-enters the range.
        let back = SplitDomain.cappedRatioWrite(
            0.85,
            base: 0.9,
            available: 1000,
            minSize: 300
        )
        #expect(abs(back - 0.85) < 1e-9)
    }
}
