import CoreGraphics
import Testing

@testable import KiwiDeskCore

// Non-grid layout tests split out of GridLayoutTests to keep both
// files under the 350-line ceiling (AGENTS.md §5): the layout
// dispatcher, monocle/floating basics, and gap geometry. Float
// rules and the retile filter live in FloatRuleRetileTests.swift
// (split out of this file for the same reason, issue #560).

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
) -> LayoutContext {
    LayoutContext(bounds: bounds, gaps: .uniform(10))
}

@Suite("Monocle and Floating")
struct SimpleLayoutTests {
    @Test("Monocle maximizes every window (bar disabled)")
    func monocle() throws {
        // The default-on indicator bar carves its strip out
        // of the usable area; without it, monocle fills the
        // whole thing (see MonocleTests for the strip).
        var context = makeContext()
        context.monocle.appBar.enabled = false
        let frames = MonocleLayout().calculateGeometry(
            for: ids(3),
            in: context
        )
        for frame in frames.values {
            #expect(frame == context.usable)
        }
    }

    @Test("Floating manages nothing")
    func floating() throws {
        let frames = FloatingLayout().calculateGeometry(
            for: ids(3),
            in: makeContext()
        )
        #expect(frames.isEmpty)
    }

    @Test("Dispatcher returns the matching system")
    func dispatch() throws {
        #expect(
            LayoutEngine.system(for: .bsp) is BspLayout
        )
        #expect(
            LayoutEngine.system(for: .monocle)
                is MonocleLayout
        )
        #expect(
            LayoutEngine.system(for: .floating)
                is FloatingLayout
        )
    }
}

@Suite("Gaps and geometry")
struct GapsGeometryTests {
    @Test("Per-edge outer gaps shape the usable area")
    func perEdgeOuter() throws {
        var gaps = Gaps()
        gaps.outer = Gaps.Outer(
            top: 5,
            bottom: 20,
            left: 10,
            right: 15
        )
        let context = LayoutContext(
            bounds: CGRect(
                x: 0,
                y: 0,
                width: 1920,
                height: 1080
            ),
            gaps: gaps
        )
        #expect(
            context.usable
                == CGRect(
                    x: 10,
                    y: 5,
                    width: 1895,
                    height: 1055
                )
        )
    }

    @Test("Uniform helper sets all six gaps")
    func uniform() throws {
        let gaps = Gaps.uniform(8)
        #expect(gaps.outer.top == 8)
        #expect(gaps.outer.right == 8)
        #expect(gaps.inner.horizontal == 8)
        #expect(gaps.inner.vertical == 8)
    }

    @Test("Coordinate flip is its own inverse")
    func flipInvolution() throws {
        let rect = CGRect(x: 100, y: 200, width: 400, height: 300)
        let flipped = GeometryUtils.flip(
            rect,
            primaryHeight: 1080
        )
        #expect(flipped.minY == 1080 - rect.maxY)
        let back = GeometryUtils.flip(
            flipped,
            primaryHeight: 1080
        )
        #expect(back == rect)
    }
}
