import CoreGraphics

/// Viewport offset computation and anchor dispatch for `ScrollingLayout`
/// (#776).
extension ScrollingLayout {
    /// Computes viewport offset for `focus` at `focusedPos`
    /// (#239, #66, #141, #966, #1388).
    ///
    /// `center`, `start` and `end` are ABSOLUTE: the focused slot
    /// rests where the anchor says even with nothing beside it,
    /// so a lone window under `start` sits at the edge with the
    /// rest of the axis empty. Only `follow` keeps the row's
    /// extent on screen — it is the anchor that promises a filled
    /// screen, and the clamp is that promise (#1388).
    public static func offset(
        anchor: ScrollingParams.Anchor,
        previous: ScrollRest?,
        focus: WindowID?,
        along: CGFloat,
        size: CGFloat,
        rowLength: CGFloat,
        focusedPos: CGFloat?
    ) -> CGFloat {
        guard let focusedPos else {
            // No slot to place (#141): hold. A fixed anchor gets
            // here once its remembered slot left the row
            // (`subject`) — bound, never lead-edge (#1388).
            let held = previous?.offset ?? 0
            return anchor.keepsRowOnScreen
                ? clampedToRow(held, along: along, rowLength: rowLength)
                : heldOnScreen(held, along: along, rowLength: rowLength)
        }
        let visibleMin = -focusedPos
        let visibleMax = along - size - focusedPos
        guard anchor.keepsRowOnScreen else {
            return anchorOffset(
                anchor: anchor,
                along: along,
                size: size,
                focusedPos: focusedPos
            )
        }
        let base =
            heldBase(
                previous: previous,
                focus: focus,
                focusedPos: focusedPos,
                focusedSpan: size,
                along: along
            ) ?? visibleMin
        return clampedToRow(
            min(max(base, visibleMin), visibleMax),
            along: along,
            rowLength: rowLength
        )
    }

    /// `follow`'s boundary: a row shorter than the axis sits at
    /// the leading edge, a longer one never shows empty margin
    /// past either end.
    private static func clampedToRow(
        _ target: CGFloat,
        along: CGFloat,
        rowLength: CGFloat
    ) -> CGFloat {
        guard rowLength > along else { return 0 }
        return min(max(target, along - rowLength), 0)
    }

    /// A held fixed-anchor rest, bounded so the row stays within
    /// the screen: a shorter row keeps its place anywhere inside
    /// the axis, a longer one shows no margin past either end.
    private static func heldOnScreen(
        _ held: CGFloat,
        along: CGFloat,
        rowLength: CGFloat
    ) -> CGFloat {
        guard rowLength > along else {
            return min(max(held, 0), along - rowLength)
        }
        return min(max(held, along - rowLength), 0)
    }

    /// Offset from which `follow` pans — nil for a never-scrolled
    /// space (#966). Two things move the focused slot and they owe
    /// opposite answers: the FOCUS moved (hold the recorded offset
    /// — scroll-into-view, #66), or every slot moved underneath an
    /// unchanged focus (a resize, neighbour change, #677 re-pack —
    /// shift by how far the slot moved so it keeps its place on
    /// screen). The recorded slot tells them apart — a reorder
    /// releases it (`Space.releaseScrollSlot`, #1353) and takes
    /// the first arm; except when it rested flush at the trailing
    /// border, the edge is what it keeps (device QA, 2026-08-27).
    private static func heldBase(
        previous: ScrollRest?,
        focus: WindowID?,
        focusedPos: CGFloat,
        focusedSpan: CGFloat,
        along: CGFloat
    ) -> CGFloat? {
        guard let previous else { return nil }
        guard let slot = previous.slot, slot.window == focus
        else { return previous.offset }
        // The trailing verdict was reached when the offset was
        // measured (`ScrollRest.Slot`) — never re-decided here;
        // the value returned is the visibility clamp's own upper
        // bound, so the clamp keeps it unchanged.
        if slot.restingOn == .trailing {
            return along - focusedSpan - focusedPos
        }
        return previous.offset + (slot.position - focusedPos)
    }

    /// Axis-relative fixed resting offset for focused slot.
    private static func anchorOffset(
        anchor: ScrollingParams.Anchor,
        along: CGFloat,
        size: CGFloat,
        focusedPos: CGFloat
    ) -> CGFloat {
        switch anchor {
        case .center:
            return (along - size) / 2 - focusedPos
        case .start:
            return -focusedPos
        case .end:
            return along - size - focusedPos
        case .follow:
            return -focusedPos
        }
    }
}
