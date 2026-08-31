import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
    gaps: Gaps = .uniform(10),
    focused: WindowID? = nil
) -> LayoutContext {
    LayoutContext(bounds: bounds, gaps: gaps, focused: focused)
}

private func approx(
    _ a: CGRect,
    _ b: CGRect,
    tolerance: CGFloat = 0.01
) -> Bool {
    abs(a.minX - b.minX) < tolerance
        && abs(a.minY - b.minY) < tolerance
        && abs(a.width - b.width) < tolerance
        && abs(a.height - b.height) < tolerance
}

@Suite("BSP layout")
struct BspLayoutTests {
    let layout = BspLayout()

    @Test("Single window fills the usable area")
    func singleWindow() throws {
        let context = makeContext()
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }

    @Test("Two windows split side by side on a wide screen")
    func twoWindows() throws {
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext()
        )
        let a = try #require(frames[w1])
        let b = try #require(frames[w2])
        #expect(
            approx(
                a,
                CGRect(x: 10, y: 10, width: 945, height: 1060)
            )
        )
        #expect(
            approx(
                b,
                CGRect(x: 965, y: 10, width: 945, height: 1060)
            )
        )
    }

    @Test("Third window splits the tall remainder vertically")
    func longestSideRecursion() throws {
        // PINNED (#660/#1181), and this is the fixture that
        // needs it most: on these bounds both strategies draw
        // the same three frames, so the flip left the one test
        // named for longest-side recursion silently running
        // `.alternating` — and no test in the tree exercised
        // `.longestSide` past depth 0 (code review, 2026-08-31).
        var context = makeContext()
        context.bsp.strategy = .longestSide
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let b = try #require(frames[w2])
        let c = try #require(frames[w3])
        #expect(
            approx(
                b,
                CGRect(x: 965, y: 10, width: 945, height: 525)
            )
        )
        #expect(
            approx(
                c,
                CGRect(x: 965, y: 545, width: 945, height: 525)
            )
        )
    }

    @Test("Alternating strategy ignores region shape")
    func alternating() throws {
        var context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 800, height: 2000)
        )
        context.bsp.strategy = .alternating
        context.minWindowSize = 100
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let a = try #require(frames[w1])
        let b = try #require(frames[w2])
        // Depth 0 splits side by side even on a portrait
        // screen.
        #expect(a.minY == b.minY)
        #expect(a.minX < b.minX)
    }

    @Test("H ratio shifts the side-by-side boundary")
    func splitRatioH() throws {
        var context = makeContext()
        context.bsp.splitRatioH = 0.7
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let a = try #require(frames[w1])
        #expect(abs(a.width - 1890 * 0.7) < 0.01)
        // Full height: the V ratio played no part here.
        #expect(abs(a.height - 1060) < 0.01)
    }

    @Test("V ratio shifts the stacked boundary")
    func splitRatioV() throws {
        // Portrait screen: longest-side stacks the first split,
        // so only the V ratio moves the boundary. The strategy
        // is PINNED rather than inherited (#660/#1181) — the
        // default is `.alternating`, which splits the first
        // level vertically whatever the screen's shape, and
        // this fixture is about the shape.
        var context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 800, height: 2000)
        )
        context.minWindowSize = 100
        context.bsp.strategy = .longestSide
        context.bsp.splitRatioV = 0.7
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let a = try #require(frames[w1])
        #expect(abs(a.height - 1970 * 0.7) < 0.01)
        #expect(abs(a.width - 780) < 0.01)
    }

    @Test("H and V ratios move their own axis only (#56)")
    func ratioIndependence() throws {
        // Three windows: depth 0 splits side by side (H),
        // depth 1 stacks the tall remainder (V) — one split
        // per axis, each following its own ratio. The strategy
        // is pinned because that arrangement is what the
        // assertions read, not because the two disagree here
        // (#660).
        var context = makeContext()
        context.bsp.strategy = .longestSide
        context.bsp.splitRatioH = 0.6
        context.bsp.splitRatioV = 0.3
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let a = try #require(frames[w1])
        let b = try #require(frames[w2])
        #expect(abs(a.width - 1890 * 0.6) < 0.01)
        // The stacked split follows only the V ratio.
        #expect(abs(b.height - 1050 * 0.3) < 0.01)
    }

    @Test("Overlap stack kicks in below min window size")
    func minSizeFallback() throws {
        // 500pt wide: halves would be ~235pt, below the 300pt
        // minimum, so BSP must stop splitting.
        let context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 500, height: 400)
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let a = try #require(frames[w1])
        let b = try #require(frames[w2])
        // Cascaded, not split: same x, offset y.
        #expect(a.minX == b.minX)
        #expect(b.minY - a.minY == OverlapStack.offset)
        #expect(a.size == b.size)
    }

    @Test("Directional inner gaps are respected")
    func directionalGaps() throws {
        var gaps = Gaps.uniform(10)
        gaps.inner.horizontal = 30
        let frames = BspLayout().calculateGeometry(
            for: [w1, w2],
            in: makeContext(gaps: gaps)
        )
        let a = try #require(frames[w1])
        let b = try #require(frames[w2])
        #expect(abs(b.minX - a.maxX - 30) < 0.01)
    }
}
