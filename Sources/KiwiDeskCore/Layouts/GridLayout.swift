import CoreGraphics

/// Grid layout system supporting dynamic and rigid tiling.
/// Both types share one ceiling: `columns`×`rows` (or the
/// auto-size screen-computed dimensions) is the most cells the
/// grid splits into — rigid fills it, dynamic balances up to it,
/// and the excess cascades in the last cell (`OverlapStack`).
public struct GridLayout: LayoutSystem {
    public init() {}

    /// What the grid draws for `count` windows: its dimensions,
    /// fill order and how many cells it lays — the last holding
    /// the overflow pile when `piles`. Nil where an equal cell
    /// would fall under `min_window_size`, which cascades the
    /// whole Space instead. The resize reads this too (#763), so
    /// a press finds a window's tracks where they were drawn.
    public struct Shape: Equatable, Sendable {
        public let columns: Int
        public let rows: Int
        public let rowMajor: Bool
        public let fillLast: Bool
        /// Cells laid: the window count, or the capacity once it
        /// overflows.
        public let cells: Int
        public let piles: Bool
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
        if count > capacity {
            return Shape(
                columns: columns,
                rows: rows,
                rowMajor: true,
                fillLast: false,
                cells: capacity,
                piles: true
            )
        }
        // Both grid types honor arrangement order (#217).
        return Shape(
            columns: columns,
            rows: rows,
            rowMajor: params.splitDirection == .horizontal,
            fillLast: params.type == .dynamic && params.fillEmptyCells,
            cells: count,
            piles: false
        )
    }

    /// `windows` in the order the grid lays them: a sticky window
    /// keeps a fully-tiled cell ahead of the pile (#414 v2).
    public static func laidOrder(
        _ windows: [WindowID],
        shape: Shape,
        sticky: Set<WindowID>
    ) -> [WindowID] {
        guard shape.piles else { return windows }
        return Array(
            OverlapStack.stickyExempt(
                windows,
                tiled: shape.cells - 1,
                sticky: sticky
            )
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
        let ordered = Self.laidOrder(
            windows,
            shape: shape,
            sticky: context.sticky
        )
        let tracks = Self.trackLengths(
            windows: ordered,
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
        guard shape.piles else {
            return Dictionary(
                uniqueKeysWithValues: zip(ordered, cells)
            )
        }
        var result: [WindowID: CGRect] = [:]
        for (index, window) in ordered[..<(shape.cells - 1)].enumerated() {
            result[window] = cells[index]
        }
        result.merge(
            OverlapStack.frames(
                for: ordered[(shape.cells - 1)...],
                in: cells[shape.cells - 1],
                minSize: context.minWindowSize
            )
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

    /// Computes cell capacity ceiling under auto-size or fixed parameters.
    func capDimensions(
        params: GridParams,
        usable: CGRect,
        gapH: CGFloat,
        gapV: CGFloat,
        minSize: MinSize
    ) -> (columns: Int, rows: Int) {
        guard params.autoSize else {
            return (max(1, params.columns), max(1, params.rows))
        }
        let cols = Int(
            (usable.width / (minSize.width + gapH)).rounded(.down)
        )
        let rows = Int(
            (usable.height / (minSize.height + gapV)).rounded(.down)
        )
        return (max(1, cols), max(1, rows))
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
