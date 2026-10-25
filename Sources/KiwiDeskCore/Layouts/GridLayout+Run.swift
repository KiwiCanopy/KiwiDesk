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
        let tracks = trackLengths(
            windows: windows,
            shape: shape,
            context: context
        )
        let cells = cellFrames(
            count: shape.cells,
            widths: tracks.widths,
            heights: tracks.heights,
            in: context.usable,
            gapH: context.gaps.inner.horizontal,
            gapV: context.gaps.inner.vertical,
            rowMajor: shape.rowMajor,
            fillLast: shape.fillLast
        )
        return [runZone(windows, shape: shape, cells: cells, context: context)]
    }

    /// The first cell of the last track — where the run begins.
    static func runStart(of shape: Shape) -> Int {
        let length = shape.rowMajor ? shape.columns : shape.rows
        return shape.cells - length
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

    /// Each shown window's cell index — a run member by the cell
    /// it is drawn in, a hidden one absent — what a resize press
    /// reads to find a window's tracks (#763).
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
        guard shape.scrolls,
            let zone = zones(for: windows, in: context)?.first
        else { return out }
        let shown =
            zone.run(in: context).map { zone.members[$0.visible] }
            ?? zone.members[...]
        for (offset, window) in shown.enumerated() {
            out[window] = min(start + offset, shape.cells - 1)
        }
        return out
    }
}
