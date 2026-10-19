import CoreGraphics

/// Where the grid's cells sit, split out of `GridLayout` for file
/// size: the track lengths the weights draw (#763) and the cell
/// frames over them.
extension GridLayout {
    /// The drawn column widths and row heights of a grid holding
    /// `windows` — the stored track weights (#763) over the
    /// gapped span, each track lifted to the floor of the windows
    /// it holds alone. The resize reads this too, so a press
    /// measures from what was drawn.
    public static func trackLengths(
        windows: [WindowID],
        shape: Shape,
        context: LayoutContext
    ) -> (widths: [CGFloat], heights: [CGFloat]) {
        let columns = shape.columns
        let rows = shape.rows
        var colFloors = Array(
            repeating: context.minWindowSize.width,
            count: columns
        )
        var rowFloors = Array(
            repeating: context.minWindowSize.height,
            count: rows
        )
        // The pile's cell holds several windows, so none of them
        // lifts its tracks alone.
        let alone = shape.piles ? shape.cells - 1 : shape.cells
        // A forced pass probes past corroborated bounds (#1055).
        let learnedCount =
            context.probesBeyondBounds ? 0 : min(alone, windows.count)
        for index in 0..<learnedCount {
            let cell = cell(index, of: shape)
            let bound = context.sizeBounds[windows[index]]
            if cell.columns.first == cell.columns.last,
                let learned = bound?.minWidth
            {
                colFloors[cell.columns.first] = max(
                    colFloors[cell.columns.first],
                    learned
                )
            }
            if cell.rows.first == cell.rows.last,
                let learned = bound?.minHeight
            {
                rowFloors[cell.rows.first] = max(
                    rowFloors[cell.rows.first],
                    learned
                )
            }
        }
        let usable = context.usable
        let widths = GridTracks.lengths(
            count: columns,
            weights: context.grid.columnWeights,
            span: GridTracks.span(
                of: usable.width,
                count: columns,
                gap: context.gaps.inner.horizontal
            ),
            floors: colFloors
        )
        let heights = GridTracks.lengths(
            count: rows,
            weights: context.grid.rowWeights,
            span: GridTracks.span(
                of: usable.height,
                count: rows,
                gap: context.gaps.inner.vertical
            ),
            floors: rowFloors
        )
        return (widths, heights)
    }

    /// The first `count` cells of an equal `columns`×`rows` grid
    /// over `region` — `cellFrames(count:widths:…)` with every
    /// track the same length. The quit grid lays its cells
    /// through this too, so the two shapes cannot drift (#1709).
    static func cellFrames(
        count: Int,
        columns: Int,
        rows: Int,
        in region: CGRect,
        gapH: CGFloat,
        gapV: CGFloat,
        rowMajor: Bool,
        fillLast: Bool
    ) -> [CGRect] {
        cellFrames(
            count: count,
            widths: GridTracks.equal(
                count: columns,
                span: GridTracks.span(
                    of: region.width,
                    count: columns,
                    gap: gapH
                )
            ),
            heights: GridTracks.equal(
                count: rows,
                span: GridTracks.span(
                    of: region.height,
                    count: rows,
                    gap: gapV
                )
            ),
            in: region,
            gapH: gapH,
            gapV: gapV,
            rowMajor: rowMajor,
            fillLast: fillLast
        )
    }

    /// The first `count` cells of a grid whose columns are
    /// `widths` and rows `heights`, in arrangement order — row by
    /// row when `rowMajor`, else column by column — the last
    /// spanning the rest of its row (column) and the gaps between
    /// when `fillLast` (`fill_empty_cells`, #763's ruling keeps
    /// the columns aligned in every row).
    static func cellFrames(
        count: Int,
        widths: [CGFloat],
        heights: [CGFloat],
        in region: CGRect,
        gapH: CGFloat,
        gapV: CGFloat,
        rowMajor: Bool,
        fillLast: Bool
    ) -> [CGRect] {
        let xs = offsets(widths, from: region.minX, gap: gapH)
        let ys = offsets(heights, from: region.minY, gap: gapV)
        return (0..<count).map { index in
            let cell = GridTracks.cell(
                index,
                count: count,
                columns: widths.count,
                rows: heights.count,
                rowMajor: rowMajor,
                fillLast: fillLast
            )
            let cols = cell.columns
            let rows = cell.rows
            return CGRect(
                x: xs[cols.first],
                y: ys[rows.first],
                width: xs[cols.last] + widths[cols.last]
                    - xs[cols.first],
                height: ys[rows.last] + heights[rows.last]
                    - ys[rows.first]
            )
        }
    }

    /// Where cell `index` of `shape` sits.
    public static func cell(
        _ index: Int,
        of shape: Shape
    ) -> GridTracks.Cell {
        GridTracks.cell(
            index,
            count: shape.cells,
            columns: shape.columns,
            rows: shape.rows,
            rowMajor: shape.rowMajor,
            fillLast: shape.fillLast
        )
    }

    /// Each track's leading edge.
    private static func offsets(
        _ lengths: [CGFloat],
        from origin: CGFloat,
        gap: CGFloat
    ) -> [CGFloat] {
        var edge = origin
        return lengths.map { length in
            defer { edge += length + gap }
            return edge
        }
    }
}
