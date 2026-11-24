import Foundation

/// A point a divider snaps to (#3517 ruling 25): a fraction of the
/// screen along the cut's axis, or where its two neighbours are
/// equal.
public enum ScreenAreaSnap: Hashable, Sendable {
    case fraction(Int, Int)
    case even
    /// In line with another divider on the same axis, so the
    /// segments of a T-junction line up (#3541).
    case divider

    /// The screen fractions a divider snaps to, in order.
    public static let fractions: [ScreenAreaSnap] = [
        .fraction(1, 4), .fraction(1, 3), .fraction(1, 2),
        .fraction(2, 3), .fraction(3, 4),
    ]
}

extension ScreenSplit {
    /// The split with `cut` moved to `position`, clamped so every
    /// area beside it keeps `floor` points along the cut's axis
    /// (ruling 25: at the floor it stops). Only the areas touching
    /// the cut move. Returns the position it landed at.
    public func moving(
        _ cut: ScreenAreaCut,
        to position: Int,
        floor: Int
    ) -> (split: ScreenSplit, position: Int) {
        let side = cut.axis == .sideBySide
        let lead = areas.filter { cut.leading.contains($0.id) }
        let trail = areas.filter { cut.trailing.contains($0.id) }
        let low = lead.map { (side ? $0.x : $0.y) + floor }.max()
        let high = trail.map {
            (side ? $0.x + $0.w : $0.y + $0.h) - floor
        }.min()
        guard let low, let high, low <= high else {
            return (self, cut.position)
        }
        let at = min(max(position, low), high)
        var copy = self
        for index in copy.areas.indices {
            var area = copy.areas[index]
            if cut.leading.contains(area.id) {
                if side { area.w = at - area.x } else { area.h = at - area.y }
            } else if cut.trailing.contains(area.id) {
                if side {
                    area.w += area.x - at
                    area.x = at
                } else {
                    area.h += area.y - at
                    area.y = at
                }
            }
            copy.areas[index] = area
        }
        return (copy, at)
    }

    /// Where `cut` would snap on a `width` × `height` screen: the
    /// ruled fractions of the screen along its axis, the point its
    /// two neighbours are equal (the leading one taking the odd
    /// point, as a split does), then every other divider on its
    /// axis.
    public func snaps(
        for cut: ScreenAreaCut,
        width: Int,
        height: Int
    ) -> [(position: Int, snap: ScreenAreaSnap)] {
        let side = cut.axis == .sideBySide
        let total = side ? width : height
        var out: [(Int, ScreenAreaSnap)] = ScreenAreaSnap.fractions
            .compactMap { snap in
                guard case .fraction(let n, let d) = snap else {
                    return nil
                }
                return ((total * n + d / 2) / d, snap)
            }
        let lead = areas.filter { cut.leading.contains($0.id) }
        let trail = areas.filter { cut.trailing.contains($0.id) }
        if lead.count == 1, trail.count == 1 {
            let lo = side ? lead[0].x : lead[0].y
            let hi = side ? trail[0].x + trail[0].w : trail[0].y + trail[0].h
            out.append((lo + (hi - lo + 1) / 2, .even))
        }
        let others =
            ScreenAreaCuts.cuts(of: areas, width: width, height: height)?
            .filter { $0.axis == cut.axis && $0.position != cut.position }
            ?? []
        for other in Set(others.map(\.position)).sorted() {
            out.append((other, .divider))
        }
        return out
    }

    /// `raw` drawn to the nearest of `snaps(for:…)` within
    /// `tolerance` points, with the snap it took; `raw` and nil
    /// where none is that near.
    public func snapped(
        _ raw: Int,
        for cut: ScreenAreaCut,
        width: Int,
        height: Int,
        tolerance: Int
    ) -> (position: Int, snap: ScreenAreaSnap?) {
        let near = snaps(for: cut, width: width, height: height)
            .filter { abs($0.position - raw) <= tolerance }
            .min { abs($0.position - raw) < abs($1.position - raw) }
        guard let near else { return (raw, nil) }
        return (near.position, near.snap)
    }
}
