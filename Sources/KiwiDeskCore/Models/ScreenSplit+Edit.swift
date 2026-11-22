import CoreGraphics
import Foundation

extension ScreenSplit {
    /// The split a `width` × `height` screen lays out in: `stored`
    /// where it is a valid split into two or more areas, else nil —
    /// the whole screen as one area 0. The one answer the placement
    /// list and the Settings picture both take (#3517).
    public static func effective(
        _ stored: ScreenSplit?,
        width: Int,
        height: Int
    ) -> ScreenSplit? {
        guard let stored, !stored.isWhole,
            ScreenArea.problem(
                with: stored.areas,
                width: width,
                height: height
            ) == nil
        else { return nil }
        return stored
    }

    /// `effective(_:width:height:)` on `display`'s own frame.
    public static func effective(
        _ stored: ScreenSplit?,
        for display: Display
    ) -> ScreenSplit? {
        effective(
            stored,
            width: Int(display.frame.width),
            height: Int(display.frame.height)
        )
    }

    /// The area a stored key lands in on this split: its own while
    /// the split holds it, else area 0 (ruling 22's fallback).
    public func landing(_ key: ScreenAreaKey) -> Int {
        areas.contains { $0.id == key.areaID } ? key.areaID : 0
    }

    /// The split's own extent in points, read from its areas, which
    /// tile the screen exactly.
    public var extent: (width: Int, height: Int) {
        (
            areas.map { $0.x + $0.w }.max() ?? 0,
            areas.map { $0.y + $0.h }.max() ?? 0
        )
    }

    /// `display` unsplit: one area 0 over its whole frame.
    public static func whole(
        of display: Display,
        after previous: ScreenSplit? = nil
    ) -> ScreenSplit {
        whole(
            width: Int(display.frame.width),
            height: Int(display.frame.height),
            after: previous
        )
    }

    /// An unsplit screen `width` × `height`: one area, id 0,
    /// keeping `previous`'s next id so a later split mints no id
    /// the screen already used (ruling 21).
    public static func whole(
        width: Int,
        height: Int,
        after previous: ScreenSplit? = nil
    ) -> ScreenSplit {
        ScreenSplit(
            areas: [ScreenArea(id: 0, x: 0, y: 0, w: width, h: height)],
            nextID: previous?.nextID
        )
    }

    /// Areas of `lengths` along `axis`, in reading order: the ids
    /// `previous` held in reading order are kept — the lead stays
    /// 0 — and the rest are minted from its next id, so re-laying a
    /// split moves no pin (rulings 14, 21).
    public static func laidOut(
        _ lengths: [Int],
        axis: ScreenAreaCut.Axis,
        width: Int,
        height: Int,
        after previous: ScreenSplit?
    ) -> ScreenSplit {
        var kept =
            previous.map { ScreenArea.readingOrder($0.areas) }?
            .map(\.id) ?? [0]
        if kept.first != 0 { kept = [0] }
        var next = previous?.nextID ?? 1
        let ids = lengths.indices.map { i -> Int in
            if i < kept.count { return kept[i] }
            defer { next += 1 }
            return next
        }
        let base = ScreenSplit(
            areas: ids.map {
                ScreenArea(id: $0, x: 0, y: 0, w: width, h: height)
            },
            nextID: next
        )
        return base.resized(lengths, axis: axis)
    }

    /// Areas given as rects, an id where the caller named one: an
    /// unnamed one takes 0 when it leads and no area holds 0, else
    /// a fresh id past `previous`'s next one and every named id
    /// (ruling 21).
    public static func adopting(
        _ entries: [(id: Int?, area: ScreenArea)],
        after previous: ScreenSplit?
    ) -> ScreenSplit {
        let named = entries.compactMap(\.id)
        var next = max(previous?.nextID ?? 1, (named.max() ?? 0) + 1)
        let ordered = entries.sorted {
            ($0.area.y, $0.area.x) < ($1.area.y, $1.area.x)
        }
        var zeroTaken = ordered.contains { $0.id == 0 }
        let areas = ordered.enumerated().map { index, entry in
            var area = entry.area
            if let id = entry.id {
                area.id = id
            } else if index == 0, !zeroTaken {
                area.id = 0
                zeroTaken = true
            } else {
                area.id = next
                next += 1
            }
            return area
        }
        return ScreenSplit(areas: areas, nextID: next)
    }

    /// Halves area `id` along `axis` (ruling 23): the left or top
    /// half keeps the id and takes the odd point; the other half
    /// gets `nextID`. Nil when no such area exists or a half would
    /// fall under `floor` points along the axis.
    public func splitting(
        _ id: Int,
        _ axis: ScreenAreaCut.Axis,
        floor: Int = ScreenArea.minimumSide
    ) -> ScreenSplit? {
        guard let at = areas.firstIndex(where: { $0.id == id })
        else { return nil }
        let area = areas[at]
        let along = axis == .sideBySide ? area.w : area.h
        let lead = along - along / 2
        let trail = along / 2
        guard trail >= max(floor, ScreenArea.minimumSide) else {
            return nil
        }
        var first = area
        var second = area
        second.id = nextID
        second.name = nil
        if axis == .sideBySide {
            first.w = lead
            second.x = area.x + lead
            second.w = trail
        } else {
            first.h = lead
            second.y = area.y + lead
            second.h = trail
        }
        var copy = self
        copy.areas[at] = first
        copy.areas.insert(second, at: at + 1)
        copy.nextID += 1
        return copy
    }

    /// Merges areas `a` and `b` (ruling 22), which must share a
    /// full edge. The survivor is area 0 when either is, else the
    /// left or top one; it keeps its name. Returns the new split and
    /// the key remap (vanished id → survivor id) every key-bearing
    /// store applies through one rewrite.
    public func merging(_ a: Int, _ b: Int)
        -> (split: ScreenSplit, vanished: Int, survivor: Int)?
    {
        guard a != b,
            let ia = areas.firstIndex(where: { $0.id == a }),
            let ib = areas.firstIndex(where: { $0.id == b })
        else { return nil }
        let ra = areas[ia].rect
        let rb = areas[ib].rect
        let union = ra.union(rb)
        guard
            union.width * union.height
                == ra.width * ra.height + rb.width * rb.height
        else { return nil }
        // The top/left one keeps its id — area 0 whenever it takes
        // part, since a valid split leads with it (`missingLeadArea`).
        let aFirst = (ra.minY, ra.minX) < (rb.minY, rb.minX)
        let (keep, drop) = aFirst ? (ia, ib) : (ib, ia)
        var survivor = areas[keep]
        survivor.x = Int(union.minX)
        survivor.y = Int(union.minY)
        survivor.w = Int(union.width)
        survivor.h = Int(union.height)
        var copy = self
        let vanished = areas[drop].id
        copy.areas[keep] = survivor
        copy.areas.remove(at: drop)
        return (copy, vanished, survivor.id)
    }

    /// Evens out the areas along the split's one axis, in reading
    /// order; odd points go to the leading areas.
    public func evenedOut(width: Int, height: Int) -> ScreenSplit {
        guard areas.count > 1,
            let cuts = ScreenAreaCuts.cuts(
                of: areas,
                width: width,
                height: height
            ),
            let axis = cuts.first?.axis
        else { return self }
        let total = axis == .sideBySide ? width : height
        return resized(
            ScreenArea.readingOrder(areas).enumerated().map {
                i,
                _ in
                total / areas.count + (i < total % areas.count ? 1 : 0)
            },
            axis: axis
        )
    }

    /// The areas, in reading order, laid out at `lengths` along
    /// `axis` — one length per area, summing to the screen.
    public func resized(
        _ lengths: [Int],
        axis: ScreenAreaCut.Axis
    ) -> ScreenSplit {
        let ordered = ScreenArea.readingOrder(areas)
        guard lengths.count == ordered.count else { return self }
        var at = 0
        var copy = self
        copy.areas = zip(ordered, lengths).map { area, length in
            var next = area
            if axis == .sideBySide {
                next.x = at
                next.w = length
            } else {
                next.y = at
                next.h = length
            }
            at += length
            return next
        }
        return copy
    }
}
