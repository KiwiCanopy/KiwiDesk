import CoreGraphics

extension Navigation {
    /// The windows sharing the focused window's overflow cascade
    /// (an `OverlapStack` pile), excluding the focused window
    /// itself; empty when it is not in a pile.
    ///
    /// Piles are read from geometry, so the one detector serves
    /// every geometric layout (grid, stack, bsp) and feeds the
    /// track layout's array-order skip alike (#172). A layout's
    /// tiled slots are disjoint — gaps hold them apart — but a
    /// cascade's members overlap heavily (the 40 pt offset is far
    /// under any window's min size). Slots are grouped into
    /// connected components of *significant* overlap; the focused
    /// window's component is its pile. A singleton component (the
    /// normal tiled case) yields the empty set, so a caller that
    /// filters on it is a no-op unless a real cascade exists.
    ///
    /// Connected components, not pairwise overlap: a deep pile's
    /// first and last members need not overlap directly, but each
    /// overlaps its neighbor, so the chain still binds them into
    /// one component.
    public static func pileMates(
        of focused: WindowID,
        among slots: [(id: WindowID, frame: CGRect)]
    ) -> Set<WindowID> {
        guard
            let start = slots.first(where: { $0.id == focused })
        else { return [] }
        var component: Set<WindowID> = [focused]
        var frontier = [start.frame]
        while let frame = frontier.popLast() {
            for slot in slots where !component.contains(slot.id) {
                guard piled(frame, slot.frame) else { continue }
                component.insert(slot.id)
                frontier.append(slot.frame)
            }
        }
        component.remove(focused)
        return component
    }

    /// Whether two slots overlap enough to be cascade-mates: a
    /// quarter of the smaller slot's area. Tiled slots never
    /// overlap (they clear this at 0); cascade members clear it
    /// easily (consecutive members share all but a 40 pt sliver).
    private static func piled(_ a: CGRect, _ b: CGRect) -> Bool {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return false }
        let overlap = intersection.width * intersection.height
        let smaller = min(
            a.width * a.height,
            b.width * b.height
        )
        guard smaller > 0 else { return false }
        return overlap >= 0.25 * smaller
    }
}
