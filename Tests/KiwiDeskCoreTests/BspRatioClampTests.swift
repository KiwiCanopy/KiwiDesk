import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// #383: an extreme BSP split ratio is clamped at render time to
/// the widest value that keeps BOTH sides ≥ `min_window_size` —
/// the overlap cascade stays reserved for a region genuinely too
/// narrow for two min-size windows at any ratio. The clamp runs
/// per region, so it holds at every recursion depth despite the
/// shared per-space scalar ratio. Mirrors the stack (#44).
@Suite("BSP split-ratio clamp (#383)")
struct BspRatioClampTests {
    let layout = BspLayout()

    private func makeContext(
        ratioH: Double = 0.5,
        ratioV: Double = 0.5,
        width: CGFloat = 1920,
        height: CGFloat = 1080
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            gaps: .uniform(10)
        )
        // Alternating keeps the split orientation per depth
        // independent of the region's shape.
        context.bsp.strategy = .alternating
        context.bsp.splitRatioH = ratioH
        context.bsp.splitRatioV = ratioV
        return context
    }

    @Test("An extreme H ratio clamps: right region pinned to min")
    func extremeHClamps() throws {
        // usable 1900, available 1890; 0.95 would leave the right
        // region ~95 pt < 300 — the old code cascaded here.
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext(ratioH: 0.95)
        )
        let left = try #require(frames[w1])
        let right = try #require(frames[w2])
        // A proper split, no cascade: side by side, right region
        // pinned to exactly min_window_size (300).
        #expect(abs(right.width - 300) < 0.01)
        #expect(abs(left.width - 1590) < 0.01)
        #expect(abs(right.minX - left.maxX - 10) < 0.01)
    }

    @Test("A tiny H ratio clamps the left region up to min")
    func tinyHClamps() throws {
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext(ratioH: 0.02)
        )
        let left = try #require(frames[w1])
        let right = try #require(frames[w2])
        #expect(abs(left.width - 300) < 0.01)
        #expect(abs(right.width - 1590) < 0.01)
    }

    @Test("A too-narrow region still cascades (honest last resort)")
    func genuineCascade() throws {
        // 500 wide can't hold two 300-pt windows at any ratio →
        // the overlap pile is correct here.
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext(ratioH: 0.5, width: 500, height: 1080)
        )
        let a = try #require(frames[w1])
        let b = try #require(frames[w2])
        // OverlapStack cascades from a shared origin, so the two
        // frames overlap rather than sitting side by side.
        #expect(a.minX == b.minX)
    }

    @Test("The clamp holds at depth: a deep V split can't pile")
    func deepSplitClampsNotPiles() throws {
        // [1, 2, 3] under alternating: w1 claims the left half
        // (H split at depth 0), then w2 over w3 split the right
        // region vertically (depth 1). An extreme V ratio that
        // would starve the deep region is clamped against that
        // region's own span, so no window collapses into a pile.
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: makeContext(ratioV: 0.98)
        )
        let top = try #require(frames[w2])
        let bottom = try #require(frames[w3])
        // Both keep at least min_window_size in height and stay
        // stacked (distinct, non-overlapping vertical bands).
        #expect(top.height >= 300 - 0.01)
        #expect(bottom.height >= 300 - 0.01)
        #expect(bottom.minY >= top.maxY - 0.01)
    }
}
