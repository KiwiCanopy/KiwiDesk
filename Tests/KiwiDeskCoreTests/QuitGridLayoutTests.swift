import CoreGraphics
import Testing

@testable import KiwiDeskCore

// One landscape display's visible frame in AX coordinates.
private let axFrame = CGRect(
    x: 0,
    y: 25,
    width: 1920,
    height: 1055
)
// One portrait display's visible frame in AX coordinates.
private let portraitFrame = CGRect(
    x: 0,
    y: 25,
    width: 1080,
    height: 1895
)
private let minSize: CGFloat = 300

private func ids(_ range: Range<UInt32>) -> [WindowID] {
    range.map { WindowID($0) }
}

/// The density target the tables below reason from, pinned as a
/// literal (#660) so a retune of `defaultTargetDepth` leaves the
/// ladder's clauses standing; the custom-target tests pass their
/// own.
private let depth = 5

private func frames(
    _ count: UInt32,
    in region: CGRect = axFrame,
    target: Int = depth
) -> [WindowID: CGRect] {
    QuitGridLayout.frames(
        for: ids(0..<count),
        in: region,
        minSize: minSize,
        targetDepth: target
    )
}

private func frame(
    _ x: CGFloat,
    _ y: CGFloat,
    _ width: CGFloat,
    _ height: CGFloat
) -> CGRect {
    CGRect(x: x, y: y, width: width, height: height)
}

/// Pure math of the `grid` quit layout (#197, #1709): the
/// near-square tile shape, the stack ladder, and the per-cell
/// cascade.
@Suite("QuitGridLayout — shape")
struct QuitGridShapeTests {
    /// Regions by aspect; the shape reads only the ratio.
    private static let r16x9 = frame(0, 0, 1920, 1080)
    private static let r16x10 = frame(0, 0, 1920, 1200)
    private static let r21x9 = frame(0, 0, 2560, 1080)
    private static let r32x9 = frame(0, 0, 3840, 1080)
    private static let r9x16 = frame(0, 0, 1080, 1920)

    @Test(
        "tiles take the nearest-square split, one to six",
        arguments: [
            // [columns, rows] for 1…6 windows.
            (r16x9, [[1, 1], [2, 1], [3, 1], [2, 2], [3, 2], [3, 2]]),
            (r16x10, [[1, 1], [2, 1], [2, 2], [2, 2], [3, 2], [3, 2]]),
            (r21x9, [[1, 1], [2, 1], [3, 1], [4, 1], [3, 2], [3, 2]]),
            (r32x9, [[1, 1], [2, 1], [3, 1], [4, 1], [3, 2], [3, 2]]),
            (r9x16, [[1, 1], [1, 2], [1, 3], [2, 2], [2, 3], [2, 3]]),
        ]
    )
    func tileShapes(region: CGRect, expected: [[Int]]) {
        for (index, shape) in expected.enumerated() {
            #expect(dims(index + 1, in: region) == shape)
        }
    }

    /// Exact ties: four on 2:1 score 4×1 and 2×2 alike (cells 1:2
    /// and 2:1), two on a square score 2×1 and 1×2 alike. The tie
    /// takes fewer splits across the short axis.
    @Test("an exact tie takes fewer splits across the short axis")
    func tieTakesFewerAcross() {
        let wide = frame(0, 0, 2000, 1000)
        let tall = frame(0, 0, 1000, 2000)
        let square = frame(0, 0, 1000, 1000)
        #expect(dims(4, in: wide) == [4, 1])
        #expect(dims(4, in: tall) == [1, 4])
        #expect(dims(2, in: square) == [2, 1])
    }

    @Test("the ladder at depth 5: 3×2, 4×2, 4×3, then 4×4")
    func ladderAtDefaultDepth() {
        #expect(dims(7) == [3, 2])
        #expect(dims(30) == [3, 2])
        #expect(dims(31) == [4, 2])
        #expect(dims(40) == [4, 2])
        #expect(dims(41) == [4, 3])
        #expect(dims(60) == [4, 3])
        #expect(dims(61) == [4, 4])
        // Past 4×4 the piles just deepen.
        #expect(dims(500) == [4, 4])
    }

    @Test("a portrait region mirrors the ladder")
    func portraitLadder() {
        #expect(dims(7, in: portraitFrame) == [2, 3])
        #expect(dims(31, in: portraitFrame) == [2, 4])
        #expect(dims(41, in: portraitFrame) == [3, 4])
        #expect(dims(61, in: portraitFrame) == [4, 4])
    }

    @Test("the ladder at depth 1 takes the rung that holds all")
    func ladderAtDepthOne() {
        #expect(dims(7, target: 1) == [4, 2])
        #expect(dims(8, target: 1) == [4, 2])
        #expect(dims(9, target: 1) == [4, 3])
        #expect(dims(13, target: 1) == [4, 4])
        #expect(dims(10_000, target: 1) == [4, 4])
    }

    @Test("a custom target moves every threshold")
    func customTargetThresholds() {
        #expect(dims(60, target: 10) == [3, 2])
        #expect(dims(61, target: 10) == [4, 2])
        #expect(dims(81, target: 10) == [4, 3])
        #expect(dims(121, target: 10) == [4, 4])
    }

    private func dims(
        _ count: Int,
        in region: CGRect = axFrame,
        target: Int = depth
    ) -> [Int] {
        let grid = QuitGridLayout.shape(
            tiles: count,
            in: region,
            targetDepth: target
        )
        return [grid.columns, grid.rows]
    }
}

@Suite("QuitGridLayout — tiles")
struct QuitGridTileTests {
    @Test("empty input yields no frames")
    func emptyInput() {
        #expect(frames(0).isEmpty)
    }

    @Test("a single window fills the region")
    func singleWindowFills() {
        #expect(frames(1)[WindowID(0)] == axFrame)
    }

    @Test("two windows sit side by side as halves")
    func twoHalves() {
        let placed = frames(2)
        #expect(placed[WindowID(0)] == frame(0, 25, 960, 1055))
        #expect(placed[WindowID(1)] == frame(960, 25, 960, 1055))
    }

    @Test("three windows share one row")
    func threeInARow() {
        let placed = frames(3)
        for index in 0..<3 {
            #expect(
                placed[WindowID(UInt32(index))]
                    == frame(CGFloat(index) * 640, 25, 640, 1055)
            )
        }
    }

    @Test("four windows take 2×2")
    func fourAsTwoByTwo() {
        let placed = frames(4)
        #expect(placed[WindowID(0)] == frame(0, 25, 960, 527.5))
        #expect(
            placed[WindowID(3)] == frame(960, 552.5, 960, 527.5)
        )
    }

    @Test("five windows: 3 + 2, the last filling its row")
    func fiveFillsTheShortRow() {
        let placed = frames(5)
        #expect(placed[WindowID(2)] == frame(1280, 25, 640, 527.5))
        #expect(placed[WindowID(3)] == frame(0, 552.5, 640, 527.5))
        #expect(
            placed[WindowID(4)] == frame(640, 552.5, 1280, 527.5)
        )
    }

    @Test("six windows fill 3×2 exactly")
    func sixFillThreeByTwo() {
        let placed = frames(6)
        #expect(
            placed[WindowID(5)] == frame(1280, 552.5, 640, 527.5)
        )
    }

    @Test("a portrait region stacks two windows top and bottom")
    func portraitTwo() {
        let placed = frames(2, in: portraitFrame)
        #expect(placed[WindowID(0)] == frame(0, 25, 1080, 947.5))
        #expect(
            placed[WindowID(1)] == frame(0, 972.5, 1080, 947.5)
        )
    }

    @Test("portrait fills column-first, the last filling down")
    func portraitFiveFillsColumnFirst() throws {
        // 2×3: windows 0–2 run down column one; 3 and 4 take
        // column two, 4 spanning the two rows left.
        let placed = frames(5, in: portraitFrame)
        let row = 1895.0 / 3
        let f2 = try #require(placed[WindowID(2)])
        let f3 = try #require(placed[WindowID(3)])
        let f4 = try #require(placed[WindowID(4)])
        #expect(f2.minX == 0)
        #expect(abs(f2.minY - (25 + 2 * row)) < 0.001)
        #expect(f3.origin == CGPoint(x: 540, y: 25))
        #expect(f4.minX == 540)
        #expect(abs(f4.minY - (25 + row)) < 0.001)
        #expect(abs(f4.height - 2 * row) < 0.001)
    }

    @Test("tiny tiles are floored at minSize")
    func minSizeFloor() throws {
        let small = CGRect(x: 0, y: 0, width: 400, height: 400)
        let placed = frames(2, in: small)
        // Halves would be 200 wide — floored to 300.
        let f0 = try #require(placed[WindowID(0)])
        #expect(f0.size == CGSize(width: 300, height: 400))
    }
}

@Suite("QuitGridLayout — piles")
struct QuitGridPileTests {
    @Test("seven windows: 3×2, the seventh piled on cell 1")
    func seventhWrapsToFirstCell() throws {
        let placed = frames(7)
        let f0 = try #require(placed[WindowID(0)])
        let f5 = try #require(placed[WindowID(5)])
        let f6 = try #require(placed[WindowID(6)])
        #expect(f0.origin == CGPoint(x: 0, y: 25))
        #expect(f5.origin == CGPoint(x: 1280, y: 552.5))
        #expect(
            f6.origin == CGPoint(x: 0, y: 25 + OverlapStack.offset)
        )
        #expect(f6.width == 640)
    }

    @Test("every cell cascades, not only the last")
    func everyCellCascades() throws {
        // 12 windows on 3×2: each cell holds 2.
        let placed = frames(12)
        for cell in 0..<6 {
            let first = try #require(
                placed[WindowID(UInt32(cell))]
            )
            let second = try #require(
                placed[WindowID(UInt32(cell + 6))]
            )
            #expect(second.minX == first.minX)
            #expect(
                second.minY == first.minY + OverlapStack.offset
            )
        }
    }

    @Test("31 windows grow the grid to 4×2")
    func growsToFourByTwo() throws {
        let placed = frames(31)
        #expect(placed.count == 31)
        let f1 = try #require(placed[WindowID(1)])
        let f4 = try #require(placed[WindowID(4)])
        #expect(f1.minX == 480)
        // Row two opens with the fifth window.
        #expect(f4.origin == CGPoint(x: 0, y: 552.5))
    }

    @Test("depth 1 deals seven into 4×2 as 4 + 3, the last filling")
    func depthOneFillsBeforeItPiles() {
        let placed = frames(7, target: 1)
        #expect(placed[WindowID(3)] == frame(1440, 25, 480, 527.5))
        #expect(placed[WindowID(4)] == frame(0, 552.5, 480, 527.5))
        #expect(
            placed[WindowID(6)] == frame(960, 552.5, 960, 527.5)
        )
    }

    @Test("a portrait region deals its piles column-first")
    func portraitDealsColumnFirst() throws {
        // 8 windows on 2×3: cells run down column one first, so
        // window 7 piles on window 1, the SECOND row's cell.
        let placed = frames(8, in: portraitFrame)
        let f1 = try #require(placed[WindowID(1)])
        let f7 = try #require(placed[WindowID(7)])
        #expect(f1.minX == 0)
        #expect(abs(f1.minY - (25 + 1895.0 / 3)) < 0.001)
        #expect(f7.minX == f1.minX)
        #expect(f7.minY == f1.minY + OverlapStack.offset)
    }

    @Test("deep bottom-row piles stay pinned on screen")
    func bottomRowPilesPinned() {
        // 160 windows → 4×4 with 10-deep piles; unpinned,
        // bottom-row cascades would run off the display.
        let placed = frames(160)
        #expect(placed.count == 160)
        for frame in placed.values {
            #expect(frame.minX >= axFrame.minX)
            #expect(frame.minY >= axFrame.minY)
            #expect(frame.minX <= axFrame.maxX - minSize)
            #expect(frame.minY <= axFrame.maxY - minSize)
        }
    }

    @Test("piles fit their cell: no spill into the row below")
    func cascadeStaysInsideCell() throws {
        // 8 windows on 3×2: cells 0 and 1 hold two each. An
        // upper-row pile spilling into row 2 would bury a
        // bottom-row header whenever the spiller is in front, so
        // the pile shrinks: its deepest ends at the cell's edge.
        let placed = frames(8)
        let f6 = try #require(placed[WindowID(6)])
        #expect(f6.maxY <= 552.5)
        let f3 = try #require(placed[WindowID(3)])
        #expect(f3.minY == 552.5)
    }
}
