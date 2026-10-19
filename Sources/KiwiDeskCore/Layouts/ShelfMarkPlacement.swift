import CoreGraphics

/// Where a hiding edge's marks and their hover bands sit along it
/// (#761): one band per mark, every band the same length, the
/// marks of an edge as one row in the shelf's order, placed where a
/// lone bar would sit (`ShelfArrangement`'s lead), and their bands
/// meeting edge to edge, so a point opens one bar. Pure.
public enum ShelfMarkPlacement {
    /// Every hover band's length along its edge, alone or paired
    /// (owner, 2026-10-19): about a Dock tile, the mark plus a
    /// margin a sideways flick lands in.
    public static let bandLength: CGFloat = 64

    /// The band of each of `bars` along an edge `length` long, as
    /// offsets from its start (left, or top on a vertical edge):
    /// adjacent, in `shelf`'s order, as one row at its alignment. A
    /// row longer than the edge starts at its start.
    public static func bands(
        for bars: Set<ShelfBar>,
        length: CGFloat,
        shelf: KiwiShelf
    ) -> [ShelfBar: ClosedRange<CGFloat>] {
        let ordered = ShelfArrangement.ordered(bars, shelf)
        let row = bandLength * CGFloat(ordered.count)
        let first = ShelfArrangement.lead(row, in: length, shelf.alignment)
        var bands: [ShelfBar: ClosedRange<CGFloat>] = [:]
        for (index, bar) in ordered.enumerated() {
            let lead = first + bandLength * CGFloat(index)
            bands[bar] = lead...(lead + bandLength)
        }
        return bands
    }
}
