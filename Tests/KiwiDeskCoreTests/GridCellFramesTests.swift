import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// `GridLayout.cellFrames` with DISTINCT non-zero gaps, so a gap
/// dropped from either axis' offset or span is seen: the quit grid
/// lays it with no gaps and the layout suites reach only the
/// column gap (#1709). A 3×3 grid over 1020×640 with a 30-pt column
/// gap and a 20-pt row gap draws 320×200 cells.
@Suite("Grid cell frames — gaps")
struct GridCellFramesTests {
    private static let region = CGRect(
        x: 0,
        y: 0,
        width: 1020,
        height: 640
    )

    private func cells(
        _ count: Int,
        rowMajor: Bool,
        fillLast: Bool
    ) -> [CGRect] {
        GridLayout.cellFrames(
            count: count,
            columns: 3,
            rows: 3,
            in: Self.region,
            gapH: 30,
            gapV: 20,
            rowMajor: rowMajor,
            fillLast: fillLast
        )
    }

    @Test("A cell's offset carries both gaps")
    func offsetCarriesBothGaps() {
        let placed = cells(9, rowMajor: true, fillLast: false)
        #expect(placed[4] == CGRect(x: 350, y: 220, width: 320, height: 200))
        #expect(placed[8] == CGRect(x: 700, y: 440, width: 320, height: 200))
    }

    @Test("A row-filling last cell spans the column gaps it covers")
    func rowFillSpansColumnGaps() {
        let placed = cells(7, rowMajor: true, fillLast: true)
        #expect(placed[6] == CGRect(x: 0, y: 440, width: 1020, height: 200))
    }

    @Test("A column-filling last cell spans the row gaps it covers")
    func columnFillSpansRowGaps() {
        let full = cells(7, rowMajor: false, fillLast: true)
        #expect(full[6] == CGRect(x: 700, y: 0, width: 320, height: 640))
        let two = cells(8, rowMajor: false, fillLast: true)
        #expect(two[7] == CGRect(x: 700, y: 220, width: 320, height: 420))
    }

    @Test("The Grid layout's second row starts one row gap down")
    func layoutRowGap() throws {
        let context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(10)
        )
        let usable = context.usable
        let windows = (1...4).map { WindowID(UInt32($0)) }
        let frames = GridLayout().calculateGeometry(
            for: windows,
            in: context
        )
        let row = (usable.height - 10) / 2
        let third = try #require(frames[WindowID(3)])
        #expect(third.minY == usable.minY + row + 10)
        #expect(third.height == row)
    }
}
