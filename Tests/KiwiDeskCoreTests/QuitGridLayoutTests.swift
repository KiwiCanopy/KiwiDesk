import CoreGraphics
import Testing

@testable import KiwiDeskCore

// One display's visible frame in AX coordinates.
private let axFrame = CGRect(
    x: 0,
    y: 25,
    width: 1920,
    height: 1055
)
private let minSize: CGFloat = 300

private func ids(_ range: Range<UInt32>) -> [WindowID] {
    range.map { WindowID($0) }
}

/// The standard density target (#281): most suites pin the
/// default behavior; the custom-target tests pass their own.
private let depth = QuitGridLayout.defaultTargetDepth

/// Pure math of the `grid` quit layout (#197): dimension
/// formula, round-robin fill, and the per-cell cascade.
@Suite("QuitGridLayout — dimension")
struct QuitGridDimensionTests {
    @Test("scales with count: ceil(sqrt(N/T)) clamped 2...4")
    func formulaThresholds() {
        // Standard target 5: ≤20 → 2×2, ≤45 → 3×3, above 4×4.
        #expect(dim(1) == 2)
        #expect(dim(20) == 2)
        #expect(dim(21) == 3)
        #expect(dim(45) == 3)
        #expect(dim(46) == 4)
        #expect(dim(80) == 4)
        // Cap: never past 4×4, however many windows.
        #expect(dim(500) == 4)
    }

    @Test("a custom target moves both growth thresholds")
    func customTargetThresholds() {
        // Target 10 (the pre-#281 constant): ≤40 → 2×2,
        // ≤90 → 3×3, above → 4×4.
        #expect(dim(40, target: 10) == 2)
        #expect(dim(41, target: 10) == 3)
        #expect(dim(90, target: 10) == 3)
        #expect(dim(91, target: 10) == 4)
        // Target 1 — aggressive spread: grows immediately.
        #expect(dim(4, target: 1) == 2)
        #expect(dim(5, target: 1) == 3)
        #expect(dim(10, target: 1) == 4)
    }

    @Test("the 2×2 floor and 4×4 cap hold for any target")
    func floorAndCapHold() {
        #expect(dim(1, target: 20) == 2)
        #expect(dim(10_000, target: 1) == 4)
    }

    private func dim(
        _ count: Int,
        target: Int = depth
    ) -> Int {
        QuitGridLayout.dimension(
            for: count,
            targetDepth: target
        )
    }
}

@Suite("QuitGridLayout — frames")
struct QuitGridFramesTests {
    @Test("empty input yields no frames")
    func emptyInput() {
        let frames = QuitGridLayout.frames(
            for: [],
            in: axFrame,
            minSize: minSize,
            targetDepth: depth
        )
        #expect(frames.isEmpty)
    }

    @Test("single window fills the top-left 2×2 cell")
    func singleWindowTopLeftCell() {
        let frames = QuitGridLayout.frames(
            for: [WindowID(1)],
            in: axFrame,
            minSize: minSize,
            targetDepth: depth
        )
        let frame = frames[WindowID(1)]
        #expect(
            frame
                == CGRect(
                    x: 0,
                    y: 25,
                    width: 960,
                    height: 527.5
                )
        )
    }

    @Test("round-robin: fifth window wraps back to cell 1")
    func roundRobinWraps() throws {
        let frames = QuitGridLayout.frames(
            for: ids(0..<5),
            in: axFrame,
            minSize: minSize,
            targetDepth: depth
        )
        let f0 = try #require(frames[WindowID(0)])
        let f1 = try #require(frames[WindowID(1)])
        let f2 = try #require(frames[WindowID(2)])
        let f3 = try #require(frames[WindowID(3)])
        let f4 = try #require(frames[WindowID(4)])
        // Row-major cells over a 2×2 grid.
        #expect(f0.origin == CGPoint(x: 0, y: 25))
        #expect(f1.origin == CGPoint(x: 960, y: 25))
        #expect(f2.origin == CGPoint(x: 0, y: 552.5))
        #expect(f3.origin == CGPoint(x: 960, y: 552.5))
        // Window 4 shares cell 0, cascaded one offset down.
        #expect(
            f4.origin
                == CGPoint(
                    x: 0,
                    y: 25 + OverlapStack.offset
                )
        )
        #expect(f4.size == f0.size)
    }

    @Test("every cell cascades, not only the last")
    func everyCellCascades() throws {
        // 8 windows on a 2×2 grid: each cell holds 2, the
        // second of each pair offset by the cascade step.
        let frames = QuitGridLayout.frames(
            for: ids(0..<8),
            in: axFrame,
            minSize: minSize,
            targetDepth: depth
        )
        for cell in 0..<4 {
            let first = try #require(
                frames[WindowID(UInt32(cell))]
            )
            let second = try #require(
                frames[WindowID(UInt32(cell + 4))]
            )
            #expect(second.minX == first.minX)
            #expect(
                second.minY
                    == first.minY + OverlapStack.offset
            )
        }
    }

    @Test("41 windows grow the grid to 3×3")
    func growsToThreeByThree() throws {
        let frames = QuitGridLayout.frames(
            for: ids(0..<41),
            in: axFrame,
            minSize: minSize,
            targetDepth: depth
        )
        #expect(frames.count == 41)
        let f1 = try #require(frames[WindowID(1)])
        // Cell width is a third of the display now.
        #expect(f1.minX == 640)
    }

    @Test("deep bottom-row piles stay pinned on screen")
    func bottomRowPilesPinned() {
        // 160 windows → 4×4 with 10-deep piles; unpinned,
        // bottom-row cascades would run 360 pt past a
        // 264-pt cell and off the display.
        let frames = QuitGridLayout.frames(
            for: ids(0..<160),
            in: axFrame,
            minSize: minSize,
            targetDepth: depth
        )
        #expect(frames.count == 160)
        for frame in frames.values {
            #expect(frame.minX >= axFrame.minX)
            #expect(frame.minY >= axFrame.minY)
            #expect(frame.minX <= axFrame.maxX - minSize)
            #expect(frame.minY <= axFrame.maxY - minSize)
        }
    }

    @Test("piles fit their cell: no spill into the row below")
    func cascadeStaysInsideCell() throws {
        // 8 windows, 2×2, 2 per cell. Quit keeps the stale
        // z-order, so an upper-row pile spilling into row 2
        // would bury a bottom-row header whenever the spiller
        // happens to be in front. The pile's windows shrink
        // instead: the deepest one ends at its cell's bottom
        // edge.
        let frames = QuitGridLayout.frames(
            for: ids(0..<8),
            in: axFrame,
            minSize: minSize,
            targetDepth: depth
        )
        // Window 4 = cell 0's second (deepest) pile entry.
        let f4 = try #require(frames[WindowID(4)])
        #expect(f4.maxY <= 552.5)
        // Bottom-row cell tops stay uncovered.
        let f2 = try #require(frames[WindowID(2)])
        #expect(f2.minY == 552.5)
    }

    @Test("raise circle: cell by cell, pile top to deepest")
    func raiseCircle() {
        // 10 windows on 2×2 — cells hold (0,4,8), (1,5,9),
        // (2,6), (3,7). The raise circle walks quadrant 1
        // through 4, each pile top slot first, deepest last,
        // so the final stacking never depends on which window
        // had focus at quit and a later row always sits above
        // the row before it.
        let order = QuitGridLayout.raiseOrder(
            for: ids(0..<10),
            targetDepth: depth
        )
        #expect(
            order == [
                WindowID(0), WindowID(4), WindowID(8),
                WindowID(1), WindowID(5), WindowID(9),
                WindowID(2), WindowID(6),
                WindowID(3), WindowID(7),
            ]
        )
    }

    @Test("raise circle matches the placed pile order")
    func raiseCircleMatchesFrames() throws {
        // The deepest-raised window of a pile must be the one
        // the frames put at the deepest offset — the two
        // partitions share one bucket function, pinned here.
        let windows = ids(0..<10)
        let frames = QuitGridLayout.frames(
            for: windows,
            in: axFrame,
            minSize: minSize,
            targetDepth: depth
        )
        let order = QuitGridLayout.raiseOrder(
            for: windows,
            targetDepth: depth
        )
        // Cell 0's pile in raise order is (0, 4, 8): their
        // frames must descend by exactly one offset each.
        let f0 = try #require(frames[order[0]])
        let f4 = try #require(frames[order[1]])
        let f8 = try #require(frames[order[2]])
        #expect(f4.minY == f0.minY + OverlapStack.offset)
        #expect(f8.minY == f4.minY + OverlapStack.offset)
    }

    @Test("tiny cells are floored at minSize")
    func minSizeFloor() throws {
        let small = CGRect(x: 0, y: 0, width: 400, height: 400)
        let frames = QuitGridLayout.frames(
            for: ids(0..<2),
            in: small,
            minSize: minSize,
            targetDepth: depth
        )
        // 2×2 cells would be 200×200 — floored to 300×300.
        let f0 = try #require(frames[WindowID(0)])
        #expect(f0.size == CGSize(width: 300, height: 300))
    }
}
