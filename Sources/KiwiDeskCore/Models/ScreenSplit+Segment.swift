import Foundation

/// One segment of a joined divider (#3611): the piece ⌥-drag moves
/// alone. A rect edit only; no cut order is stored.
extension ScreenSplit {
    /// The piece of `cut` around `cross` (a point along the cut, in
    /// screen points): it runs between the nearest points on either
    /// side where no area of the two boxes the cut parts crosses the
    /// line, so each box is cut there too. The whole cut where no
    /// such point lies inside it. Moving the result moves only the
    /// areas beside that piece, and the rects still read as a split.
    public func segment(
        of cut: ScreenAreaCut,
        at cross: Int
    ) -> ScreenAreaCut {
        let across: ScreenAreaCut.Axis =
            cut.axis == .sideBySide ? .stacked : .sideBySide
        let lead = areas.filter { cut.leading.contains($0.id) }
        let trail = areas.filter { cut.trailing.contains($0.id) }
        let parted = Set(sides(of: cut))
        let boxes = areas.filter { parted.contains($0.id) }
        let breaks = Set(boxes.map { ScreenAreaRuns.lo($0, across) })
            .filter { $0 > cut.start && $0 < cut.end }
            .filter { at in
                !boxes.contains {
                    ScreenAreaRuns.lo($0, across) < at
                        && ScreenAreaRuns.hi($0, across) > at
                }
            }
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

    /// Every area of the two run members `cut` lies between.
    private func sides(of cut: ScreenAreaCut) -> [Int] {
        guard
            let run = runs.first(where: {
                $0.axis == cut.axis && $0.crossStart == cut.start
                    && $0.crossEnd == cut.end
                    && $0.members.contains { $0.end == cut.position }
            }),
            let index = run.members.firstIndex(where: {
                $0.end == cut.position
            }),
            run.members.indices.contains(index + 1)
        else { return [] }
        return run.members[index].areas + run.members[index + 1].areas
    }

    /// Whether `cut` holds more than one segment, where an ⌥-drag
    /// moves less than the whole line.
    public func isJoined(_ cut: ScreenAreaCut) -> Bool {
        segment(of: cut, at: cut.start).end != cut.end
    }

    /// The split with `segment` (from `segment(of:at:)`) moved to
    /// `position`, as `moving` clamps it. A belt: self at the
    /// segment's own position where the moved rects leave no
    /// divider to read, which no known split produces.
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
