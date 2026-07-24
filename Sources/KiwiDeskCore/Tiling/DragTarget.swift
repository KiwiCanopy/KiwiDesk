import CoreGraphics

/// The drop-target rule, shared by the live preview and the
/// final drop so the highlight can never disagree with what
/// the drop does: a drag targets the slot that contains the
/// mouse CURSOR (AX coordinates), not the dragged window's
/// frame center.
///
/// Cursor-keyed, not center-keyed, so a large window dragged
/// onto a smaller display resolves its target the moment the
/// cursor crosses over — a big window's center lags on the
/// origin display long after the pointer (and the user's
/// intent) has left it (#492). Dragging is a pointer gesture;
/// intent lives at the cursor, matching how macOS itself
/// decides which display a drag belongs to. The slot pool
/// already spans every visible display (`calculatedFrames`),
/// so the cursor alone selects both the display and the slot.
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
