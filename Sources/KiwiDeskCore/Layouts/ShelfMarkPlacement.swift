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

    /// One edge's row: each bar's band and the pocket's, offsets
    /// from the edge's start.
    public struct Row: Equatable, Sendable {
        public var bars: [ShelfBar: ClosedRange<CGFloat>]
        /// The pocket handle's band, at the row's leaning end; nil
        /// where no pocket stands on the edge (#2678).
        public var pocket: ClosedRange<CGFloat>?
    }

    /// The band of each of `bars` along an edge `length` long, as
    /// offsets from its start (left, or top on a vertical edge):
    /// adjacent, in `shelf`'s order, as one row at its alignment —
    /// the pocket's handle one band more at the row's end where
    /// `pocketLeansEnd`, at its start where false, none where nil.
    /// A row longer than the edge starts at its start.
    public static func row(
        for bars: Set<ShelfBar>,
        pocketLeansEnd: Bool?,
        length: CGFloat,
        shelf: KiwiShelf
    ) -> Row {
        let ordered = ShelfArrangement.ordered(bars, shelf)
        let count = ordered.count + (pocketLeansEnd == nil ? 0 : 1)
        let row = bandLength * CGFloat(count)
        var next = ShelfArrangement.lead(row, in: length, shelf.alignment)
        let take = { () -> ClosedRange<CGFloat> in
            defer { next += bandLength }
            return next...(next + bandLength)
        }
        var pocket: ClosedRange<CGFloat>?
        if pocketLeansEnd == false { pocket = take() }
        var bands: [ShelfBar: ClosedRange<CGFloat>] = [:]
        for bar in ordered { bands[bar] = take() }
        if pocketLeansEnd == true { pocket = take() }
        return Row(bars: bands, pocket: pocket)
    }
}
