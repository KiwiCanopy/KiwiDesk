import CoreGraphics

/// Grid layout system supporting dynamic and rigid tiling.
/// Both types share one ceiling: `columns`×`rows` (or the
/// auto-size screen-computed dimensions) is the most cells the
/// grid splits into — rigid fills it, dynamic balances up to it,
/// and the excess cascades in the last cell (`OverlapStack`).
public struct GridLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let usable = context.usable
        let count = windows.count
        guard count > 0 else { return [:] }

        let params = context.grid
        let gapH = context.gaps.inner.horizontal
        let gapV = context.gaps.inner.vertical
        let cap = capDimensions(
            params: params,
            usable: usable,
            gapH: gapH,
            gapV: gapV,
            minSize: context.minWindowSize
        )
        let (columns, rows) = Self.dimensions(
            count: count,
            params: params,
            cap: cap
        )

        let size = Self.cellSize(
            columns: columns,
            rows: rows,
            in: usable,
            gapH: gapH,
            gapV: gapV
        )
        if min(size.width, size.height) < context.minWindowSize {
            return OverlapStack.frames(
                for: windows,
                in: usable,
                minSize: context.minWindowSize
            )
        }

        var result: [WindowID: CGRect] = [:]
        let capacity = columns * rows

        if count > capacity {
            let cells = Self.cellFrames(
                count: capacity,
                columns: columns,
                rows: rows,
                in: usable,
                gapH: gapH,
                gapV: gapV,
                columnFirst: true,
                fillLast: false
            )
            // Sticky windows preserve a fully-tiled cell (#414 v2).
            let ordered = OverlapStack.stickyExempt(
                windows,
                tiled: capacity - 1,
                sticky: context.sticky
            )
            for (index, window)
                in ordered[..<(capacity - 1)].enumerated()
            {
                result[window] = cells[index]
            }
            result.merge(
                OverlapStack.frames(
                    for: ordered[(capacity - 1)...],
                    in: cells[capacity - 1],
                    minSize: context.minWindowSize
                )
            ) { _, new in new }
            return result
        }

        // Both grid types honor arrangement order (#217).
        let cells = Self.cellFrames(
            count: count,
            columns: columns,
            rows: rows,
            in: usable,
            gapH: gapH,
            gapV: gapV,
            columnFirst: params.splitDirection == .horizontal,
            fillLast: params.type == .dynamic
                && params.fillEmptyCells
        )
        for (window, frame) in zip(windows, cells) {
            result[window] = frame
        }
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

    /// The first `count` cells of a `columns`×`rows` grid over
    /// `region`, in arrangement order — row by row when
    /// `columnFirst`, else column by column — the last spanning
    /// the rest of its row (column) when `fillLast`
    /// (`fill_empty_cells`). The quit grid lays its cells
    /// through this too, so the two shapes cannot drift (#1709).
    public static func cellFrames(
        count: Int,
        columns: Int,
        rows: Int,
        in region: CGRect,
        gapH: CGFloat,
        gapV: CGFloat,
        columnFirst: Bool,
        fillLast: Bool
    ) -> [CGRect] {
        let size = cellSize(
            columns: columns,
            rows: rows,
            in: region,
            gapH: gapH,
            gapV: gapV
        )
        return (0..<count).map { index in
            let col = columnFirst ? index % columns : index / rows
            let row = columnFirst ? index / columns : index % rows
            let fills = fillLast && index == count - 1
            let colSpan = fills && columnFirst ? columns - col : 1
            let rowSpan = fills && !columnFirst ? rows - row : 1
            return CGRect(
                x: region.minX
                    + CGFloat(col) * (size.width + gapH),
                y: region.minY
                    + CGFloat(row) * (size.height + gapV),
                width: size.width * CGFloat(colSpan)
                    + gapH * CGFloat(colSpan - 1),
                height: size.height * CGFloat(rowSpan)
                    + gapV * CGFloat(rowSpan - 1)
            )
        }
    }

    /// Computes cell capacity ceiling under auto-size or fixed parameters.
    func capDimensions(
        params: GridParams,
        usable: CGRect,
        gapH: CGFloat,
        gapV: CGFloat,
        minSize: CGFloat
    ) -> (columns: Int, rows: Int) {
        guard params.autoSize else {
            return (max(1, params.columns), max(1, params.rows))
        }
        let cols = Int(
            (usable.width / (minSize + gapH)).rounded(.down)
        )
        let rows = Int(
            (usable.height / (minSize + gapV)).rounded(.down)
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
