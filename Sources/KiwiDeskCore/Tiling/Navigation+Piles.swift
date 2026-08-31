import CoreGraphics

extension Navigation {
    /// Returns windows sharing the focused window's overlap pile,
    /// read from GEOMETRY so one detector serves every layout
    /// (#172). Connected components of significant overlap, not
    /// pairwise: a deep pile's ends need not overlap directly. A
    /// singleton component yields the empty set.
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

    /// Cascade-mates overlap by ≥ a quarter of the smaller
    /// slot's area: tiled slots never overlap (0), cascade
    /// members share all but a 40 pt sliver — both clear it with
    /// margin.
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
