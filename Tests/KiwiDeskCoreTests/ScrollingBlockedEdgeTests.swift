import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)
private let w4 = WindowID(4)
private let w5 = WindowID(5)

/// The blocked-edge hard stop (#878): an edge with another
/// screen beyond it (`context.screenNeighbors`) is a wall — a
/// scrolled-out slot stops flush at the border, fully on its
/// own screen, and stacks behind the viewport instead of
/// overhanging onto the neighbor. Open edges keep the #142
/// overhang-with-sliver pins (`ScrollingLayoutTests`).
@Suite("Scrolling blocked-edge hard stop (#878)")
struct ScrollingBlockedEdgeTests {
    let layout = ScrollingLayout()

    /// The #142 suites' round-number geometry: 1000pt usable
    /// width, 400pt slots, no inner gap.
    private func pinContext(focused: WindowID) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1020, height: 1080),
            gaps: .uniform(10),
            focused: focused
        )
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .points(400)
        context.gaps.inner.horizontal = 0
        return context
    }

    @Test("A right wall stops every scrolled-out slot flush")
    func rightWallStopsFlush() throws {
        var context = pinContext(focused: w1)
        context.scrollOffset = 0
        context.screenNeighbors = ScreenNeighbors(right: true)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4, w5],
            in: context
        )
        // Far slots stop AT the border — no sliver past it.
        for id in [w4, w5] {
            let frame = try #require(frames[id])
            #expect(frame.maxX == context.usable.maxX)
        }
        // A partially visible slot whose body would cross the
        // wall clamps flush too: the excess becomes underlap
        // behind its viewport neighbor, never overhang past the
        // seam (w3's ideal lead is 800 of a 1000pt axis).
        #expect(
            try #require(frames[w3]).maxX == context.usable.maxX
        )
        // The wall never resizes: position and z-order are the
        // whole mechanism.
        for frame in frames.values {
            #expect(frame.width == 400)
            #expect(frame.height == context.usable.height)
        }
        // The focused slot is untouched at the leading edge.
        #expect(
            try #require(frames[w1]).minX == context.usable.minX
        )
    }

    @Test("A left wall mirrors the stop on the leading edge")
    func leftWallStopsFlush() throws {
        var context = pinContext(focused: w5)
        context.scrollOffset = -1000
        context.screenNeighbors = ScreenNeighbors(left: true)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4, w5],
            in: context
        )
        for id in [w1, w2, w3] {
            let frame = try #require(frames[id])
            #expect(frame.minX == context.usable.minX)
        }
        // w4 (lead 200) crosses no edge and must not move.
        #expect(
            try #require(frames[w4]).minX
                == context.usable.minX + 200
        )
        #expect(
            try #require(frames[w5]).maxX == context.usable.maxX
        )
    }

    @Test("Walls on both sides act independently")
    func bothWalls() throws {
        var context = pinContext(focused: w3)
        context.scrollOffset = -800
        context.screenNeighbors = ScreenNeighbors(
            left: true,
            right: true
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4, w5],
            in: context
        )
        for id in [w1, w2] {
            let frame = try #require(frames[id])
            #expect(frame.minX == context.usable.minX)
        }
        #expect(
            try #require(frames[w5]).maxX == context.usable.maxX
        )
        // The focused slot (lead 0) and the fully visible w4
        // (lead 400) are untouched between the walls.
        #expect(
            try #require(frames[w3]).minX == context.usable.minX
        )
        #expect(
            try #require(frames[w4]).minX
                == context.usable.minX + 400
        )
    }

    @Test("A wall on one side leaves the other edge open")
    func oppositeEdgeStaysOpen() throws {
        // Left neighbor, right edge open: far-right slots keep
        // the #142 overhang with its `edgePeek` sliver — the
        // wall is per edge, never per axis.
        var context = pinContext(focused: w1)
        context.scrollOffset = 0
        context.screenNeighbors = ScreenNeighbors(left: true)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4, w5],
            in: context
        )
        let peek = ScrollingLayout.edgePeek
        for id in [w4, w5] {
            let frame = try #require(frames[id])
            #expect(
                frame.minX == context.usable.maxX - peek
            )
        }
    }

    @Test("A screen below walls vertical scrolling's bottom")
    func bottomWallVertical() throws {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(10),
            focused: w1
        )
        // Bar on the left (edge is absolute since #293), carving
        // width, so bottom snapping is against the full usable
        // height — the vertical suite's fixture.
        context.scrolling.appBar.edge = .left
        context.scrolling.orientation = .vertical
        context.scrolling.slotSize = .points(400)
        context.scrollOffset = 0
        context.screenNeighbors = ScreenNeighbors(bottom: true)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        // w3's ideal lead (820, stride 410) overhangs the
        // 1060pt usable height; the wall stops it flush.
        #expect(
            try #require(frames[w3]).maxY == context.usable.maxY
        )
        #expect(try #require(frames[w3]).height == 400)
        // The focused top slot is untouched.
        #expect(
            try #require(frames[w1]).minY == context.usable.minY
        )
    }
}
