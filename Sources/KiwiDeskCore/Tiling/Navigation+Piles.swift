import CoreGraphics

extension Navigation {
    /// Returns windows sharing the focused window's overlap pile (#172).
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

    /// Checks if two frames overlap by at least 25% of smaller slot area.
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
