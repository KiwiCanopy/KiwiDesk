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
}
