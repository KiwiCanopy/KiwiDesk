import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)
private let w4 = WindowID(4)
private let w5 = WindowID(5)

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

    @Test("Split ratio shifts the boundary")
    func splitRatio() throws {
        var context = makeContext()
        context.bsp.splitRatio = 0.7
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let a = try #require(frames[w1])
        #expect(abs(a.width - 1890 * 0.7) < 0.01)
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
        let old = #"{"masterCount":2,"masterRatio":0.7}"#
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

    @Test("Spawn placement master inserts at index 0")
    func spawnPlacement() throws {
        var space = Space(id: "s", windows: [w1, w2])
        space.insert(w3, placement: .master)
        #expect(space.windows == [w3, w1, w2])
        space.insert(w4, placement: .stack)
        #expect(space.windows == [w3, w1, w2, w4])
    }
}

@Suite("Scrolling layout")
struct ScrollingLayoutTests {
    let layout = ScrollingLayout()

    @Test("Single window scales to the full width")
    func singleWindow() throws {
        let context = makeContext()
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }

    @Test("Focused column is centered")
    func centerAnchor() throws {
        let context = makeContext(focused: w2)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let focused = try #require(frames[w2])
        #expect(abs(focused.midX - context.usable.midX) < 0.01)
        #expect(focused.width == 800)
    }

    @Test("First column snaps to the left edge")
    func leftBoundary() throws {
        let context = makeContext(focused: w1)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let first = try #require(frames[w1])
        #expect(first.minX == context.usable.minX)
    }

    @Test("Last column snaps to the right edge")
    func rightBoundary() throws {
        let context = makeContext(focused: w3)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let last = try #require(frames[w3])
        #expect(abs(last.maxX - context.usable.maxX) < 0.01)
    }

    @Test("Columns keep fixed width and full height")
    func columnDimensions() throws {
        let context = makeContext(focused: w2)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        for frame in frames.values {
            #expect(frame.width == 800)
            #expect(frame.height == context.usable.height)
        }
    }

    @Test("Short rows left-align without margins")
    func shortRow() throws {
        var context = makeContext(focused: w2)
        context.scrolling.windowWidth = 400
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let first = try #require(frames[w1])
        #expect(first.minX == context.usable.minX)
    }
}
