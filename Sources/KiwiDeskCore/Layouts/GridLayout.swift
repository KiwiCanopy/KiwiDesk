import CoreGraphics

/// Grid layout system supporting dynamic and rigid tiling.
/// Both types share one ceiling: `columns`×`rows` (or the
/// auto-size screen-computed dimensions, both capped at what fits
/// `min_window_size`) is the most cells the grid splits into —
/// rigid fills it, dynamic balances up to it, and the excess
/// scrolls through the last track (#2541, `GridLayout+Run`).
public struct GridLayout: LayoutSystem {
    public init() {}

    /// What the grid draws for `count` windows: its dimensions,
    /// fill order and how many cells it lays — the last track
    /// scrolling the excess when `scrolls`. Nil where an equal
    /// cell would fall under `min_window_size` even at 1 × 1,
    /// which cascades the whole Space instead. The resize reads
    /// this too (#763), so a press finds a window's tracks where
    /// they were drawn.
    public struct Shape: Equatable, Sendable {
        public let columns: Int
        public let rows: Int
        public let rowMajor: Bool
        public let fillLast: Bool
        /// Cells laid: the window count, or the capacity once it
        /// overflows.
        public let cells: Int
        /// More windows than cells: the last track scrolls.
        public let scrolls: Bool
    }

    public static func shape(
        count: Int,
        in context: LayoutContext
    ) -> Shape? {
        guard count > 0 else { return nil }
        let params = context.grid
        let gapH = context.gaps.inner.horizontal
        let gapV = context.gaps.inner.vertical
        let cap = GridLayout().capDimensions(
            params: params,
            usable: context.usable,
            gapH: gapH,
            gapV: gapV,
            minSize: context.minWindowSize
        )
        let (columns, rows) = dimensions(
            count: count,
            params: params,
            cap: cap
        )
        let size = cellSize(
            columns: columns,
            rows: rows,
            in: context.usable,
            gapH: gapH,
            gapV: gapV
        )
        let floor = context.minWindowSize
        guard size.width >= floor.width, size.height >= floor.height
        else { return nil }
        let capacity = columns * rows
        let scrolls = count > capacity
        // Both grid types honor arrangement order (#217); the
        // overflow scrolls along it too (#2541).
        return Shape(
            columns: columns,
            rows: rows,
            rowMajor: params.splitDirection == .horizontal,
            fillLast: !scrolls && params.type == .dynamic
                && params.fillEmptyCells,
            cells: min(count, capacity),
            scrolls: scrolls
        )
    }

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }
        guard let shape = Self.shape(count: windows.count, in: context)
        else {
            return OverlapStack.frames(
                for: windows,
                in: context.usable,
                minSize: context.minWindowSize
            )
        }
        let tracks = Self.trackLengths(
            windows: windows,
            shape: shape,
            context: context
        )
        let cells = Self.cellFrames(
            count: shape.cells,
            widths: tracks.widths,
            heights: tracks.heights,
            in: context.usable,
            gapH: context.gaps.inner.horizontal,
            gapV: context.gaps.inner.vertical,
            rowMajor: shape.rowMajor,
            fillLast: shape.fillLast
        )
        guard shape.scrolls else {
            return Dictionary(
                uniqueKeysWithValues: zip(windows, cells)
            )
        }
        let start = Self.runStart(of: shape)
        var result = Dictionary(
            uniqueKeysWithValues: zip(windows[..<start], cells)
        )
        result.merge(
            Self.runZone(
                windows,
                shape: shape,
                cells: cells,
                context: context
            ).frames(in: context)
        ) { _, new in new }
        return result
    }

    /// One cell's size in a `columns`×`rows` grid over `region`.
    static func cellSize(
        columns: Int,
        rows: Int,
        in region: CGRect,
        gapH: CGFloat,
        gapV: CGFloat
    ) -> CGSize {
        CGSize(
            width: (region.width - gapH * CGFloat(columns - 1))
                / CGFloat(columns),
            height: (region.height - gapV * CGFloat(rows - 1))
                / CGFloat(rows)
        )
    }

    /// The cell ceiling: as many columns and rows as fit at
    /// `min_window_size`, or the fixed ones capped at that — a
    /// fixed grid's dimensions are a maximum (#2541).
    func capDimensions(
        params: GridParams,
        usable: CGRect,
        gapH: CGFloat,
        gapV: CGFloat,
        minSize: MinSize
    ) -> (columns: Int, rows: Int) {
        let cols = max(
            1,
            Int((usable.width / (minSize.width + gapH)).rounded(.down))
        )
        let rows = max(
            1,
            Int((usable.height / (minSize.height + gapV)).rounded(.down))
        )
        guard params.autoSize else {
            return (
                min(max(1, params.columns), cols),
                min(max(1, params.rows), rows)
            )
        }
        return (cols, rows)
    }

    /// Resolves grid dimensions bounded by the cap — the cap
    /// bounds the CEILING, not the growth, so a dynamic grid stays
    /// tight until it hits it. Public + static because the
    /// Settings preview needs the whole rule or it subdivides past
    /// where the real grid stops (#712).
    public static func dimensions(
        count: Int,
        params: GridParams,
        cap: (columns: Int, rows: Int)
    ) -> (columns: Int, rows: Int) {
        switch params.type {
        case .rigid:
            return cap
        case .dynamic:
            let balanced = Self.balanced(
                count: count,
                splitDirection: params.splitDirection
            )
            var columns = min(balanced.columns, cap.columns)
            var rows = min(balanced.rows, cap.rows)
            if columns * rows < count {
                rows = min(cap.rows, Self.ceilDiv(count, columns))
            }
            if columns * rows < count {
                columns = min(cap.columns, Self.ceilDiv(count, rows))
            }
            return (columns, rows)
        }
    }

    private static func ceilDiv(_ a: Int, _ b: Int) -> Int {
        (a + b - 1) / b
    }

    /// Auto-balanced column/row count for window count (#678 turn 10).
    public static func balanced(
        count: Int,
        splitDirection: GridParams.SplitDirection
    ) -> (columns: Int, rows: Int) {
        let n = Double(count)
        switch splitDirection {
        case .horizontal:
            let columns = Int(n.squareRoot().rounded(.up))
            let rows = Int((n / Double(columns)).rounded(.up))
            return (columns, rows)
        case .vertical:
            let rows = Int(n.squareRoot().rounded(.up))
            let columns = Int((n / Double(rows)).rounded(.up))
            return (columns, rows)
        }
    }
}
