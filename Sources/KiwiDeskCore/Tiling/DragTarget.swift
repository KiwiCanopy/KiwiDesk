import CoreGraphics

/// Cursor-based swap target determination for window dragging (#492).
enum DragTarget {
    static func swapTarget(
        of id: WindowID,
        at point: CGPoint,
        slots: [WindowID: CGRect]
    ) -> WindowID? {
        let hits = slots.filter { entry in
            entry.key != id && entry.value.contains(point)
        }
        // Slots can overlap (stack overflow cascade). The hit
        // slot with the lowest top edge is the one visually
        // under the point: cascade windows sit progressively
        // lower and are raised on top of the previous ones,
        // so each slot's visible part is the strip between
        // its top edge and the next slot's. Ties (identical
        // slots) break by id, never by dictionary order.
        return hits.max { a, b in
            (a.value.minY, a.key.raw)
                < (b.value.minY, b.key.raw)
        }?.key
    }
}
