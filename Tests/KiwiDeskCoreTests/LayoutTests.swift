import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)
private let w4 = WindowID(4)
private let w5 = WindowID(5)
private let w6 = WindowID(6)

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
    func shortestSideRecursion() throws {
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: makeContext()
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
        // Portrait screen: shortest-side stacks the first
        // split, so only the V ratio moves the boundary.
        var context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 800, height: 2000)
        )
        context.minWindowSize = 100
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
        // per axis, each following its own ratio.
        var context = makeContext()
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

@Suite("Stack layout")
struct StackLayoutTests {
    let layout = StackLayout()

    @Test("Master alone gets the full width")
    func masterOnly() throws {
        let context = makeContext()
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }

    @Test("Master zone takes masterRatio of the width")
    func masterAndStack() throws {
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext()
        )
        let master = try #require(frames[w1])
        let stack = try #require(frames[w2])
        #expect(abs(master.width - 1890 * 0.6) < 0.01)
        #expect(abs(stack.minX - master.maxX - 10) < 0.01)
        #expect(master.height == 1060)
        #expect(stack.height == 1060)
    }

    @Test("Stack zone distributes windows evenly")
    func stackDistribution() throws {
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4],
            in: makeContext()
        )
        let s1 = try #require(frames[w2])
        let s2 = try #require(frames[w3])
        let s3 = try #require(frames[w4])
        let expected = (1060.0 - 20) / 3
        #expect(abs(s1.height - expected) < 0.01)
        #expect(abs(s2.minY - s1.maxY - 10) < 0.01)
        #expect(abs(s3.minY - s2.maxY - 10) < 0.01)
    }

    @Test("masterCount 2 stacks two masters vertically")
    func multiMaster() throws {
        var context = makeContext()
        context.stack.masterCount = 2
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let m1 = try #require(frames[w1])
        let m2 = try #require(frames[w2])
        #expect(m1.minX == m2.minX)
        #expect(m2.minY > m1.minY)
        #expect(frames[w3]?.minX ?? 0 > m1.maxX)
    }

    @Test("Column overflow keeps full windows, cascades rest")
    func partialOverflow() throws {
        // Usable 780pt tall; four stack windows can't all get
        // 300pt, but one can — the other three cascade below.
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4, w5],
            in: makeContext(
                bounds: CGRect(
                    x: 0,
                    y: 0,
                    width: 1920,
                    height: 800
                )
            )
        )
        let top = try #require(frames[w2])
        let c1 = try #require(frames[w3])
        let c2 = try #require(frames[w4])
        let c3 = try #require(frames[w5])
        // First stack window stays fully tiled...
        #expect(top.height >= 300)
        // ...the rest cascade with title-bar offsets.
        #expect(c2.minY - c1.minY == OverlapStack.offset)
        #expect(c3.minY - c2.minY == OverlapStack.offset)
        #expect(c1.height == 300)
        // The cascade ends exactly at the region bottom.
        #expect(abs(c3.maxY - 790) < 0.01)
    }

    @Test("cascade_all overflow style cascades the whole zone")
    func cascadeAllStyle() throws {
        // Same crowded column as partialOverflow, old-style.
        var context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 800)
        )
        context.stack.overflowStyle = .cascadeAll
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4, w5],
            in: context
        )
        let s1 = try #require(frames[w2])
        let s2 = try #require(frames[w3])
        let s3 = try #require(frames[w4])
        let s4 = try #require(frames[w5])
        #expect(s2.minY - s1.minY == OverlapStack.offset)
        #expect(s3.minY - s2.minY == OverlapStack.offset)
        #expect(s4.minY - s3.minY == OverlapStack.offset)
        #expect(s1.size == s4.size)
    }

    @Test("StackParams decodes profiles missing new fields")
    func decodeOldProfile() throws {
        // A profile saved before overflowStyle existed.
        let old = #"{"master_count":2,"master_ratio":0.7}"#
        let params = try JSONDecoder().decode(
            StackParams.self,
            from: Data(old.utf8)
        )
        #expect(params.masterCount == 2)
        #expect(params.masterRatio == 0.7)
        #expect(params.overflowStyle == .cascadeOverflow)
    }

    @Test("Promote swaps with the last master window")
    func promote() throws {
        var space = Space(id: "s", windows: [w1, w2, w3])
        space.promote(w3, masterCount: 1)
        #expect(space.windows == [w3, w2, w1])
        // Already master: no-op.
        space.promote(w3, masterCount: 1)
        #expect(space.windows == [w3, w2, w1])
    }

    @Test("Demote swaps with the first stack window")
    func demote() throws {
        var space = Space(id: "s", windows: [w1, w2, w3])
        space.demote(w1, masterCount: 1)
        #expect(space.windows == [w2, w1, w3])
        // Already in stack: no-op.
        space.demote(w1, masterCount: 1)
        #expect(space.windows == [w2, w1, w3])
    }

    @Test("Spawn placements insert at the right position")
    func spawnPlacement() throws {
        var space = Space(id: "s", windows: [w1, w2])
        space.insert(w3, placement: .first)
        #expect(space.windows == [w3, w1, w2])
        space.insert(w4, placement: .last)
        #expect(space.windows == [w3, w1, w2, w4])
        // Relative placements anchor on the focused window
        // and fall back to appending without one.
        space.focused = w1
        space.insert(w5, placement: .beforeFocused)
        #expect(space.windows == [w3, w5, w1, w2, w4])
        space.insert(w6, placement: .afterFocused)
        #expect(space.windows == [w3, w5, w1, w6, w2, w4])
    }
}
