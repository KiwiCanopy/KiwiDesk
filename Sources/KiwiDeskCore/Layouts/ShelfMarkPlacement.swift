import CoreGraphics

/// Where a hiding edge's marks and their hover bands sit along it
/// (#761): one band per mark, every band the same length, the
/// marks of an edge as one row placed where a lone bar would sit
/// and their bands meeting edge to edge, so a point opens one bar.
/// Pure, so the Settings picture and the live shelf ask one rule.
public enum ShelfMarkPlacement {
    /// Every hover band's length along its edge, alone or paired
    /// (owner, 2026-10-19): about a Dock tile, the mark plus a
    /// margin a sideways flick lands in.
    public static let bandLength: CGFloat = 64

    /// The bands of `count` marks along an edge `length` long, as
    /// offsets from its start (left, or top on a vertical edge),
    /// in order: adjacent, as one row at `alignment`. A row longer
    /// than the edge starts at its start.
    public static func bands(
        count: Int,
        length: CGFloat,
        alignment: KiwiShelf.Alignment
    ) -> [ClosedRange<CGFloat>] {
        guard count > 0 else { return [] }
        let row = bandLength * CGFloat(count)
        let start: CGFloat
        switch alignment {
        case .start: start = 0
        case .center: start = (length - row) / 2
        case .end: start = length - row
        }
        let first = max(0, start)
        return (0..<count).map { index in
            let lead = first + bandLength * CGFloat(index)
            return lead...(lead + bandLength)
        }
    }
}
