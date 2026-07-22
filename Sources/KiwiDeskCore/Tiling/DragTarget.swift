import CoreGraphics

/// The drop-target rule, shared by the live preview and the
/// final drop so the highlight can never disagree with what
/// the drop does: a drag targets the slot that contains the
/// dragged frame's center.
enum DragTarget {
    static func swapTarget(
        of id: WindowID,
        frame: CGRect,
        slots: [WindowID: CGRect]
    ) -> WindowID? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let hits = slots.filter { entry in
            entry.key != id && entry.value.contains(center)
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
