import CoreGraphics

/// The Grid's overflow (#2541): the windows past its cells scroll
/// through the last track along the fill order — the last row when
/// rows fill first, else the last column — as one `RunZone`.
extension GridLayout {
    /// The zones the grid scrolls: the last track while the grid
    /// overflows, none while every window has a cell, nil where
    /// the whole Space piles (`RunZone.zones`).
    public static func zones(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [RunZone]? {
        guard let shape = shape(count: windows.count, in: context)
        else { return nil }
        guard shape.scrolls else { return [] }
        return [
            runZone(
                windows,
                shape: shape,
                cells: cells(for: windows, shape: shape, in: context),
                context: context
            )
        ]
    }

    /// The cells the grid draws for `windows` under `shape` — the
    /// one reading the render and the run share, so a cover never
    /// describes a run the render did not draw.
    static func cells(
        for windows: [WindowID],
        shape: Shape,
        in context: LayoutContext
    ) -> [CGRect] {
        let tracks = trackLengths(
            windows: windows,
            shape: shape,
            context: context
        )
        return cellFrames(
            count: shape.cells,
            widths: tracks.widths,
            heights: tracks.heights,
            in: context.usable,
            gapH: context.gaps.inner.horizontal,
            gapV: context.gaps.inner.vertical,
            rowMajor: shape.rowMajor,
            fillLast: shape.fillLast
        )
    }

    /// The first cell of the last track of a full `columns` ×
    /// `rows` grid — where the run begins. The Settings preview
    /// reads it too.
    public static func runStart(
        columns: Int,
        rows: Int,
        rowMajor: Bool
    ) -> Int {
        columns * rows - (rowMajor ? columns : rows)
    }

    static func runStart(of shape: Shape) -> Int {
        runStart(
            columns: shape.columns,
            rows: shape.rows,
            rowMajor: shape.rowMajor
        )
    }

    /// The last track's run over `cells`: every window from its
    /// first cell on. A fixed grid shows exactly the track's cells;
    /// an auto-sized one as many windows as fit at their floor
    /// (owner, 2026-10-25).
    static func runZone(
        _ windows: [WindowID],
        shape: Shape,
        cells: [CGRect],
        context: LayoutContext
    ) -> RunZone {
        let track = Array(cells[runStart(of: shape)...])
        let region = track.dropFirst().reduce(track[0]) { $0.union($1) }
        return RunZone(
            members: Array(windows[runStart(of: shape)...]),
            region: region,
            vertical: !shape.rowMajor,
            slots: context.grid.autoSize ? nil : track
        )
    }

    /// Each shown window's cell index — a run member by the last-
    /// track cell nearest its drawn frame's centre, a hidden one
    /// absent — what a resize press reads to find a window's
    /// tracks (#763).
    public static func cellIndices(
        of windows: [WindowID],
        shape: Shape,
        in context: LayoutContext
    ) -> [WindowID: Int] {
        let start = shape.scrolls ? runStart(of: shape) : shape.cells
        var out: [WindowID: Int] = [:]
        for (index, window) in windows.prefix(start).enumerated() {
            out[window] = index
        }
        guard shape.scrolls else { return out }
        let cells = cells(for: windows, shape: shape, in: context)
        let zone = runZone(
            windows,
            shape: shape,
            cells: cells,
            context: context
        )
        let frames = zone.frames(in: context)
        let shown =
            zone.run(in: context).map { zone.members[$0.visible] }
            ?? zone.members[...]
        for window in shown {
            guard let frame = frames[window] else { continue }
            out[window] = (start..<shape.cells).min {
                distance(cells[$0], frame) < distance(cells[$1], frame)
            }
        }
        return out
    }

    private static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        hypot(a.midX - b.midX, a.midY - b.midY)
    }
}
