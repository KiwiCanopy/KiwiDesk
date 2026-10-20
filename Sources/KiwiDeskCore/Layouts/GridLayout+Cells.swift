import CoreGraphics

/// Where the grid's cells sit, split out of `GridLayout` for file
/// size: the track lengths the weights draw (#763) and the cell
/// frames over them.
extension GridLayout {
    /// One track's floor and the window that sets it — nil where
    /// `min_window_size` alone binds.
    public struct TrackFloor: Equatable, Sendable {
        public let size: CGFloat
        public let carrier: WindowID?
    }

    /// Each column's floor (`horizontal`) or each row's: the
    /// configured minimum, raised by the learned minimum of every
    /// window whose cell lies in that track alone (#763). The pile
    /// holds several windows, so none of them lifts a track, and a
    /// forced pass probes past learned bounds (#1055). The one
    /// reading the render and the resize share.
    public static func trackFloors(
        windows: [WindowID],
        shape: Shape,
        horizontal: Bool,
        context: LayoutContext
    ) -> [TrackFloor] {
        let count = horizontal ? shape.columns : shape.rows
        let configured = context.minWindowSize.along(
            horizontal: horizontal
        )
        var floors = Array(
            repeating: TrackFloor(size: configured, carrier: nil),
            count: count
        )
        let alone = shape.piles ? shape.cells - 1 : shape.cells
        let learned =
            context.probesBeyondBounds ? 0 : min(alone, windows.count)
        for index in 0..<learned {
            let cell = cell(index, of: shape)
            let span = horizontal ? cell.columns : cell.rows
            guard span.first == span.last else { continue }
            let floor = context.learnedFloor(
                of: windows[index],
                horizontal: horizontal
            )
            if floor > floors[span.first].size {
                floors[span.first] = TrackFloor(
                    size: floor,
                    carrier: windows[index]
                )
            }
        }
        return floors
    }

    /// The drawn lengths of one axis's tracks under `weights` —
    /// what the render draws and what a press solves against.
    public static func axisLengths(
        weights: [Double],
        floors: [TrackFloor],
        horizontal: Bool,
        context: LayoutContext
    ) -> [CGFloat] {
        let usable = context.usable
        return GridTracks.lengths(
            count: floors.count,
            weights: weights,
            span: GridTracks.span(
                of: horizontal ? usable.width : usable.height,
                count: floors.count,
                gap: horizontal
                    ? context.gaps.inner.horizontal
                    : context.gaps.inner.vertical
            ),
            floors: floors.map(\.size),
            minimum: context.minWindowSize.along(horizontal: horizontal)
        )
    }

    /// The drawn column widths and row heights of a grid holding
    /// `windows`: the stored track weights (#763) over the gapped
    /// span, each track lifted to its `trackFloors` floor.
    public static func trackLengths(
        windows: [WindowID],
        shape: Shape,
        context: LayoutContext
    ) -> (widths: [CGFloat], heights: [CGFloat]) {
        func lengths(_ horizontal: Bool) -> [CGFloat] {
            axisLengths(
                weights: horizontal
                    ? context.grid.columnWeights
                    : context.grid.rowWeights,
                floors: trackFloors(
                    windows: windows,
                    shape: shape,
                    horizontal: horizontal,
                    context: context
                ),
                horizontal: horizontal,
                context: context
            )
        }
        return (lengths(true), lengths(false))
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
