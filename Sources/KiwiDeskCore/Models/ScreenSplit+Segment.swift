import Foundation

/// One segment of a joined divider (#3611): the piece ⌥-drag moves
/// alone. A rect edit only; no cut order is stored.
extension ScreenSplit {
    /// The piece of `cut` around `cross` (a point along the cut, in
    /// screen points): it runs between the nearest points on either
    /// side where an area edge meets the line from both sides. The
    /// whole cut where no such point lies inside it. Moving the
    /// result moves only the areas beside that piece.
    public func segment(
        of cut: ScreenAreaCut,
        at cross: Int
    ) -> ScreenAreaCut {
        let across: ScreenAreaCut.Axis =
            cut.axis == .sideBySide ? .stacked : .sideBySide
        let lead = areas.filter { cut.leading.contains($0.id) }
        let trail = areas.filter { cut.trailing.contains($0.id) }
        func edges(_ side: [ScreenArea]) -> Set<Int> {
            Set(
                side.flatMap {
                    [
                        ScreenAreaRuns.lo($0, across),
                        ScreenAreaRuns.hi($0, across),
                    ]
                }
            )
        }
        let breaks = edges(lead).intersection(edges(trail))
            .filter { $0 > cut.start && $0 < cut.end }
        let start = breaks.filter { $0 <= cross }.max() ?? cut.start
        let end = breaks.filter { $0 > cross }.min() ?? cut.end
        func inside(_ side: [ScreenArea]) -> [Int] {
            ScreenArea.readingOrder(
                side.filter {
                    ScreenAreaRuns.lo($0, across) >= start
                        && ScreenAreaRuns.hi($0, across) <= end
                }
            ).map(\.id)
        }
        return ScreenAreaCut(
            axis: cut.axis,
            position: cut.position,
            start: start,
            end: end,
            leading: inside(lead),
            trailing: inside(trail)
        )
    }

    /// The split with `segment` (from `segment(of:at:)`) moved to
    /// `position`, as `moving` clamps it; self at the segment's own
    /// position where the moved rects leave no divider to read.
    public func movingSegment(
        _ segment: ScreenAreaCut,
        to position: Int,
        floor: Int
    ) -> (split: ScreenSplit, position: Int) {
        let moved = moving(segment, to: position, floor: floor)
        let readable =
            ScreenAreaCuts.cuts(
                of: moved.split.areas,
                width: extent.width,
                height: extent.height
            ) != nil
        return readable ? moved : (self, segment.position)
    }
}
