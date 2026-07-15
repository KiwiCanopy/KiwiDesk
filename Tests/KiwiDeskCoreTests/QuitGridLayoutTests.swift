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
            minSize: minSize
        )
        #expect(frames.isEmpty)
    }

    @Test("single window fills the top-left 2×2 cell")
    func singleWindowTopLeftCell() {
        let frames = QuitGridLayout.frames(
            for: [WindowID(1)],
            in: axFrame,
            minSize: minSize
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
            minSize: minSize
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
            minSize: minSize
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
            minSize: minSize
        )
        #expect(frames.count == 41)
        let f1 = try #require(frames[WindowID(1)])
        // Cell width is a third of the display now.
        #expect(f1.minX == 640)
    }

    @Test("tiny cells are floored at minSize")
    func minSizeFloor() throws {
        let small = CGRect(x: 0, y: 0, width: 400, height: 400)
        let frames = QuitGridLayout.frames(
            for: ids(0..<2),
            in: small,
            minSize: minSize
        )
        // 2×2 cells would be 200×200 — floored to 300×300.
        let f0 = try #require(frames[WindowID(0)])
        #expect(f0.size == CGSize(width: 300, height: 300))
    }
}
