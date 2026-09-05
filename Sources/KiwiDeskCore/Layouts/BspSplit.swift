import CoreGraphics

/// The geometry of a BSP space's FIRST split on one axis: which
/// side of it a slot sits on, and which slots take part in it at
/// all. Shared by every resize path — the keyboard `resize`
/// verb, the shared capped writer and the mouse drag translator
/// — which is why it is not inside any one of them (#122/#1259).
///
/// It reads slots rather than a tree because there is no tree to
/// read: BSP is a dwindle over the flat array with two shared
/// ratio scalars (AGENTS.md §5), so a split's shape exists only
/// in the frames it produced.
public enum BspSplit {
    /// Direction (+1 / -1) to move BSP ratio to grow target slot (#122).
    public static func side(
        slot: CGRect,
        bounds: CGRect,
        horizontal: Bool
    ) -> CGFloat {
        horizontal
            ? (slot.midX <= bounds.midX ? 1 : -1)
            : (slot.midY <= bounds.midY ? 1 : -1)
    }

    /// How far a slot's extent may fall short of the tiled
    /// extent and still count as spanning it: the layout's own
    /// arithmetic, so sub-point rounding is the only gap to
    /// absorb. A window that really is split off is short by an
    /// inner gap plus a min-size share, never by a point.
    private static let spanTolerance: CGFloat = 1

    /// Sorts tiled slots onto the two sides of the first split
    /// on one axis, DROPPING the windows that take no part in
    /// it (#1259): a slot spanning the whole tiled extent lies
    /// above every split of that orientation, so no ratio move
    /// can change its size. It belongs to neither side, and a
    /// side that counts it can come back naming it as the
    /// window that cannot move — which tells the user the wrong
    /// window is stuck.
    ///
    /// The extent is the UNION of the slots rather than the
    /// layout region: the tiling fills its region, so the union
    /// is the same number already inset by the outer gaps,
    /// which the region is not. `bounds` stays the region for
    /// the side comparison itself (#537).
    public static func sides(
        of windows: some Sequence<WindowID>,
        slots: [WindowID: CGRect],
        bounds: CGRect,
        horizontal: Bool
    ) -> (first: [WindowID], second: [WindowID]) {
        let placed = windows.compactMap { id in
            slots[id].map { (id: id, slot: $0) }
        }
        // A region too small for two minimum-size windows makes
        // the layout give up and PILE them (`OverlapStack`).
        // A piled window's size answers to no ratio, so it takes
        // no part in the split — the same verdict as a full-span
        // one, and reached separately because the extent test
        // cannot see it: the cascade offsets each copy, so the
        // union outgrows every slot on the offset axis and the
        // whole pile reads as participants. Dropped ONE BY ONE
        // rather than disabling the space, since a pile deep in
        // the tree leaves its ancestors dividing normally
        // (#1258, review).
        let piled = Set(
            placed.filter { one in
                placed.contains {
                    $0.id != one.id && $0.slot.intersects(one.slot)
                }
            }.map(\.id)
        )
        let extent = placed.reduce(CGRect.null) {
            $0.union($1.slot)
        }
        let whole = horizontal ? extent.width : extent.height
        var first: [WindowID] = []
        var second: [WindowID] = []
        for (id, slot) in placed {
            guard !piled.contains(id) else { continue }
            let own = horizontal ? slot.width : slot.height
            guard own < whole - spanTolerance else { continue }
            let side = side(
                slot: slot,
                bounds: bounds,
                horizontal: horizontal
            )
            if side > 0 {
                first.append(id)
            } else {
                second.append(id)
            }
        }
        return (first, second)
    }
}
