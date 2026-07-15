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

/// Pure math of the `grid` quit layout (#197): dimension
/// formula, round-robin fill, and the per-cell cascade.
@Suite("QuitGridLayout — dimension")
struct QuitGridDimensionTests {
    @Test("scales with count: ceil(sqrt(N/10)) clamped 2...4")
    func formulaThresholds() {
        #expect(QuitGridLayout.dimension(for: 1) == 2)
        #expect(QuitGridLayout.dimension(for: 40) == 2)
        #expect(QuitGridLayout.dimension(for: 41) == 3)
        #expect(QuitGridLayout.dimension(for: 90) == 3)
        #expect(QuitGridLayout.dimension(for: 91) == 4)
        #expect(QuitGridLayout.dimension(for: 160) == 4)
        // Cap: never past 4×4, however many windows.
        #expect(QuitGridLayout.dimension(for: 500) == 4)
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
            frontToBack: [:]
        )
        #expect(frames.isEmpty)
    }

    @Test("single window fills the top-left 2×2 cell")
    func singleWindowTopLeftCell() {
        let frames = QuitGridLayout.frames(
            for: [WindowID(1)],
            in: axFrame,
            minSize: minSize,
            frontToBack: [:]
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
            frontToBack: [:]
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
            frontToBack: [:]
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
            frontToBack: [:]
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
            frontToBack: [:]
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
            frontToBack: [:]
        )
        // Window 4 = cell 0's second (deepest) pile entry.
        let f4 = try #require(frames[WindowID(4)])
        #expect(f4.maxY <= 552.5)
        // Bottom-row cell tops stay uncovered.
        let f2 = try #require(frames[WindowID(2)])
        #expect(f2.minY == 552.5)
    }

    @Test("pile slots follow z-order: frontmost lands deepest")
    func pileFollowsZOrder() throws {
        // 5 windows on 2×2: cell 0 holds windows 0 and 4.
        // Make window 0 frontmost (rank 0) and window 4 a
        // background window (rank 3). Quit never raises, so
        // window 0 must take the deeper slot — in the top
        // slot its body would bury window 4's title bar.
        let frames = QuitGridLayout.frames(
            for: ids(0..<5),
            in: axFrame,
            minSize: minSize,
            frontToBack: [WindowID(0): 0, WindowID(4): 3]
        )
        let f0 = try #require(frames[WindowID(0)])
        let f4 = try #require(frames[WindowID(4)])
        #expect(f4.origin == CGPoint(x: 0, y: 25))
        #expect(
            f0.origin
                == CGPoint(
                    x: 0,
                    y: 25 + OverlapStack.offset
                )
        )
    }

    @Test("unranked windows count as backmost, order kept")
    func unrankedTreatedBackmost() throws {
        // Only window 0 is ranked (frontmost). Windows 4 and
        // 8 share its cell unranked: they take the upper
        // slots in round-robin order; window 0 sinks to the
        // bottom of the pile.
        let frames = QuitGridLayout.frames(
            for: ids(0..<9),
            in: axFrame,
            minSize: minSize,
            frontToBack: [WindowID(0): 0]
        )
        let f0 = try #require(frames[WindowID(0)])
        let f4 = try #require(frames[WindowID(4)])
        let f8 = try #require(frames[WindowID(8)])
        #expect(f4.minY == 25)
        #expect(f8.minY == 25 + OverlapStack.offset)
        #expect(f0.minY == 25 + 2 * OverlapStack.offset)
    }

    @Test("tiny cells are floored at minSize")
    func minSizeFloor() throws {
        let small = CGRect(x: 0, y: 0, width: 400, height: 400)
        let frames = QuitGridLayout.frames(
            for: ids(0..<2),
            in: small,
            minSize: minSize,
            frontToBack: [:]
        )
        // 2×2 cells would be 200×200 — floored to 300×300.
        let f0 = try #require(frames[WindowID(0)])
        #expect(f0.size == CGSize(width: 300, height: 300))
    }
}
