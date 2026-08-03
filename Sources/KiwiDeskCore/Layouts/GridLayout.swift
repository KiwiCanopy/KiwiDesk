import CoreGraphics

/// Grid layout: dynamic (auto-balanced, square-ish) or rigid
/// (fixed user-defined columns x rows).
///
/// Both types share one ceiling. `columns`x`rows` (or, with
/// `auto_size`, the screen-computed dimensions) is the most
/// cells the grid ever splits into: a rigid grid always fills
/// it, a dynamic grid auto-balances *up to* it. Past capacity
/// the excess windows cascade in the last cell — the same
/// `OverlapStack` overflow either type falls back to.
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
        let (columns, rows) = dimensions(
            count: count,
            params: params,
            cap: cap
        )

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

        // Overflow: excess windows beyond the capped capacity
        // stack in the last cell. Dynamic reaches here only once
        // the balanced arrangement is clamped to the cap; rigid
        // whenever the fixed grid fills up.
        if count > capacity {
            // Sticky windows keep a fully-tiled cell (#414 v2):
            // one caught past the cap trades places with the
            // last non-sticky tiled window, which piles instead.
            let ordered = OverlapStack.stickyExempt(
                windows,
                tiled: capacity - 1,
                sticky: context.sticky
            )
            for (index, window)
                in ordered[..<(capacity - 1)].enumerated()
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
                    for: ordered[(capacity - 1)...],
                    in: lastCell,
                    minSize: context.minWindowSize
                )
            ) { _, new in new }
            return result
        }

        let fillLast =
            params.type == .dynamic && params.fillEmptySpace
        // Both grid types honour the arrange order (#217): columns
        // first fills row-major (across a row, then down), rows
        // first column-major (down a column, then across). It is a
        // fill-order setting, not only a dynamic-growth one.
        let columnFirst =
            params.splitDirection == .horizontal

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

    /// The grid's cell ceiling: the screen-computed dimensions
    /// when `auto_size` is on, otherwise the typed `columns` x
    /// `rows`. Auto-size fits as many min-size cells as each
    /// axis allows, so a landscape monitor yields more columns
    /// than rows.
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

    /// Grid dimensions (columns x rows) for a window count,
    /// bounded by the `cap`. Rigid uses the cap verbatim;
    /// dynamic auto-balances a square-ish arrangement clamped to
    /// the cap — the cap bounds the ceiling, not the growth, so a
    /// dynamic grid stays tight until it hits it. When the
    /// balanced arrangement's orientation fights the cap's (a
    /// wide balance against a tall cap), the unpinned axis grows
    /// to use the cap's full capacity before the count overflows.
    func dimensions(
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

    /// Ceiling of `a / b` for positive integers.
    private static func ceilDiv(_ a: Int, _ b: Int) -> Int {
        (a + b - 1) / b
    }

    /// The square-ish auto-balanced arrangement for a window
    /// count, before any cap. Column-first (horizontal split)
    /// grows columns first: 1x1, 2x1, 2x2, 3x2, 3x3, …;
    /// row-first mirrors it.
    ///
    /// Public because the Settings preview balances its own
    /// window count through it (#678 turn 10) rather than
    /// reproducing the arithmetic: a preview holding a private
    /// copy of this rule is a picture of the layout that stops
    /// agreeing with it the day the rule changes. Pure and
    /// screen-free, so exposing it hands out no state.
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
