import CoreGraphics
import Foundation

extension ScreenSplit {
    /// An unsplit screen `width` × `height`: one area, id 0.
    public static func whole(width: Int, height: Int) -> ScreenSplit {
        ScreenSplit(areas: [ScreenArea(id: 0, x: 0, y: 0, w: width, h: height)]
        )
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
        let (keep, drop): (Int, Int)
        if a == 0 || b == 0 {
            (keep, drop) = a == 0 ? (ia, ib) : (ib, ia)
        } else {
            let aFirst = (ra.minY, ra.minX) < (rb.minY, rb.minX)
            (keep, drop) = aFirst ? (ia, ib) : (ib, ia)
        }
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
