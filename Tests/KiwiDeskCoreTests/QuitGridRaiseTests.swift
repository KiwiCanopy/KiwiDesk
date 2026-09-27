import CoreGraphics
import Testing

@testable import KiwiDeskCore

// One landscape and one portrait display's visible frame in AX
// coordinates.
private let axFrame = CGRect(x: 0, y: 25, width: 1920, height: 1055)
private let portraitFrame = CGRect(
    x: 0,
    y: 25,
    width: 1080,
    height: 1895
)
private let minSize: CGFloat = 300
// The density target these counts reason from, pinned (#660).
private let depth = 5

private func ids(_ range: Range<UInt32>) -> [WindowID] {
    range.map { WindowID($0) }
}

/// The quit grid's raise circle (#688) and its one partition
/// with `frames` (#1709 reshaped the grid, not the promise).
@Suite("QuitGridLayout — raise circle")
struct QuitGridRaiseTests {
    @Test("raise circle: cell by cell, pile top to deepest")
    func raiseCircle() {
        // 10 windows on 3×2 — cells hold (0,6), (1,7), (2,8),
        // (3,9), (4), (5). Each pile top first, deepest last, so
        // the final stacking never depends on which window had
        // focus at quit and a later row sits above the one
        // before it.
        let order = QuitGridLayout.raiseOrder(
            for: ids(0..<10),
            in: axFrame,
            targetDepth: depth
        )
        let expected: [UInt32] = [0, 6, 1, 7, 2, 8, 3, 9, 4, 5]
        #expect(order == expected.map(WindowID.init))
    }

    @Test("tiles raise in arrangement order")
    func tilesRaiseInOrder() {
        let order = QuitGridLayout.raiseOrder(
            for: ids(0..<5),
            in: axFrame,
            targetDepth: depth
        )
        #expect(order == ids(0..<5))
    }

    @Test(
        "raise circle matches the placed piles",
        arguments: [
            (UInt32(10), axFrame), (UInt32(9), portraitFrame),
            (UInt32(20), axFrame), (UInt32(35), axFrame),
            (UInt32(50), portraitFrame),
        ]
    )
    func raiseCircleMatchesFrames(
        count: UInt32,
        region: CGRect
    ) throws {
        // Every pile in raise order descends by exactly one
        // offset per member, and the piles come in the fill
        // order the frames draw — row by row on a landscape
        // region, column by column on a portrait one: `frames`
        // and `raiseOrder` share one partition (#688).
        let placed = QuitGridLayout.frames(
            for: ids(0..<count),
            in: region,
            minSize: minSize,
            targetDepth: depth
        )
        let order = QuitGridLayout.raiseOrder(
            for: ids(0..<count),
            in: region,
            targetDepth: depth
        )
        #expect(order.count == placed.count)
        #expect(Set(order) == Set(placed.keys))
        let origins = placed.values.map(\.origin)
        func isPileTop(_ frame: CGRect) -> Bool {
            !origins.contains(
                CGPoint(
                    x: frame.minX,
                    y: frame.minY - OverlapStack.offset
                )
            )
        }
        let grid = QuitGridLayout.shape(
            tiles: Int(count),
            in: region,
            targetDepth: depth
        )
        #expect(
            placed.values.filter(isPileTop).count
                == grid.columns * grid.rows
        )
        for (above, below) in zip(order, order.dropFirst()) {
            let top = try #require(placed[above])
            let next = try #require(placed[below])
            if !isPileTop(next) {
                #expect(next.minX == top.minX)
                #expect(next.minY == top.minY + OverlapStack.offset)
            }
        }
        let columnFirst = region.height > region.width
        let tops = order.compactMap { placed[$0] }.filter(isPileTop)
        for (earlier, later) in zip(tops, tops.dropFirst()) {
            let (a, b) =
                columnFirst
                ? ((earlier.minX, earlier.minY), (later.minX, later.minY))
                : ((earlier.minY, earlier.minX), (later.minY, later.minX))
            #expect(a < b)
        }
    }
}
