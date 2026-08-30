import CoreGraphics

/// Viewport offset computation and anchor dispatch for `ScrollingLayout`
/// (#776).
extension ScrollingLayout {
    /// Computes viewport offset for `focus` at `focusedPos`
    /// (#239, #66, #141, #966).
    public static func offset(
        anchor: ScrollingParams.Anchor,
        previous: ScrollRest?,
        focus: WindowID?,
        along: CGFloat,
        size: CGFloat,
        rowLength: CGFloat,
        focusedPos: CGFloat?
    ) -> CGFloat {
        var target: CGFloat
        if let focusedPos {
            let visibleMin = -focusedPos
            let visibleMax = along - size - focusedPos
            switch anchor {
            case .follow:
                let base =
                    heldBase(
                        previous: previous,
                        focus: focus,
                        focusedPos: focusedPos,
                        focusedSpan: size,
                        along: along
                    ) ?? visibleMin
                target = min(max(base, visibleMin), visibleMax)
            case .center, .start, .end:
                let resting = anchorOffset(
                    anchor: anchor,
                    along: along,
                    size: size,
                    focusedPos: focusedPos
                )
                target = min(max(resting, visibleMin), visibleMax)
            }
        } else {
            target = previous?.offset ?? 0
        }

        guard rowLength > along else { return 0 }
        return min(max(target, along - rowLength), 0)
    }

    /// Offset from which `follow` pans — nil for a never-scrolled
    /// space (#966). Two things move the focused slot and they owe
    /// opposite answers: the FOCUS moved (hold the recorded offset
    /// — scroll-into-view, #66), or every slot moved underneath an
    /// unchanged focus (a resize, swap, neighbour change, #677
    /// re-pack — shift by how far the slot moved so it keeps its
    /// place on screen). The recorded slot tells them apart;
    /// except when it rested flush at the trailing border, the
    /// edge is what it keeps (device QA, 2026-08-27).
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
