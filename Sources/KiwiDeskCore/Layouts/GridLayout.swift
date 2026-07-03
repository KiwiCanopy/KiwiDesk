import CoreGraphics

/// Grid layout: dynamic (auto-balanced, square-ish) or rigid
/// (fixed user-defined columns x rows).
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
        let (columns, rows) = dimensions(
            count: count,
            params: params
        )

        let gapH = context.gaps.inner.horizontal
        let gapV = context.gaps.inner.vertical
        let cellWidth =
            (usable.width - gapH * CGFloat(columns - 1))
            / CGFloat(columns)
        let cellHeight =
            (usable.height - gapV * CGFloat(rows - 1))
            / CGFloat(rows)
        if min(cellWidth, cellHeight) < context.minWindowSize {
            return OverlapStack.frames(
                for: windows,
                in: usable,
                minSize: context.minWindowSize
            )
        }

        func cell(
            col: Int,
            row: Int,
            colSpan: Int = 1,
            rowSpan: Int = 1
        ) -> CGRect {
            CGRect(
                x: usable.minX
                    + CGFloat(col) * (cellWidth + gapH),
                y: usable.minY
                    + CGFloat(row) * (cellHeight + gapV),
                width: cellWidth * CGFloat(colSpan)
                    + gapH * CGFloat(colSpan - 1),
                height: cellHeight * CGFloat(rowSpan)
                    + gapV * CGFloat(rowSpan - 1)
            )
        }

        var result: [WindowID: CGRect] = [:]
        let capacity = columns * rows

        // Rigid overflow: excess windows stack in the last cell.
        if params.type == .rigid, count > capacity {
            for (index, window)
                in windows[..<(capacity - 1)].enumerated()
            {
                result[window] = cell(
                    col: index % columns,
                    row: index / columns
                )
            }
            let lastCell = cell(
                col: columns - 1,
                row: rows - 1
            )
            result.merge(
                OverlapStack.frames(
                    for: windows[(capacity - 1)...],
                    in: lastCell,
                    minSize: context.minWindowSize
                )
            ) { _, new in new }
            return result
        }

        let fillLast =
            params.type == .dynamic && params.fillEmptySpace
        let columnFirst =
            params.splitDirection == .horizontal
            || params.type == .rigid

        for (index, window) in windows.enumerated() {
            let col: Int
            let row: Int
            if columnFirst {
                // Row-major filling.
                col = index % columns
                row = index / columns
            } else {
                // Column-major filling.
                col = index / rows
                row = index % rows
            }
            let isLast = index == count - 1
            if isLast, fillLast, columnFirst {
                result[window] = cell(
                    col: col,
                    row: row,
                    colSpan: columns - col
                )
            } else if isLast, fillLast {
                result[window] = cell(
                    col: col,
                    row: row,
                    rowSpan: rows - row
                )
            } else {
                result[window] = cell(col: col, row: row)
            }
        }
        return result
    }

    /// Grid dimensions (columns x rows) for a window count.
    func dimensions(
        count: Int,
        params: GridParams
    ) -> (columns: Int, rows: Int) {
        switch params.type {
        case .rigid:
            return (max(1, params.columns), max(1, params.rows))
        case .dynamic:
            let n = Double(count)
            switch params.splitDirection {
            case .horizontal:
                // Column-first: 1x1, 2x1, 2x2, 3x2, 3x3, ...
                let columns = Int(n.squareRoot().rounded(.up))
                let rows = Int(
                    (n / Double(columns)).rounded(.up)
                )
                return (columns, rows)
            case .vertical:
                // Row-first: 1x1, 1x2, 2x2, 2x3, 3x3, ...
                let rows = Int(n.squareRoot().rounded(.up))
                let columns = Int(
                    (n / Double(rows)).rounded(.up)
                )
                return (columns, rows)
            }
        }
    }
}
