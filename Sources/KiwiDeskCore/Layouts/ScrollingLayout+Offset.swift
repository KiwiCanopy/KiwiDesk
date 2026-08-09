import CoreGraphics

/// The viewport-offset half of `ScrollingLayout`, split at the
/// file ceiling: the anchor dispatch and the clamps that keep a
/// row from revealing empty margin past its ends. Pure maths —
/// `calculateGeometry` and `viewportOffset` next door both
/// resolve through it, and so does the Settings preview (#776).
extension ScrollingLayout {
    /// The viewport offset for a focus at `focusedPos`, given the
    /// offset from the last tile (`previous`).
    ///
    /// Dispatches on `anchor`, not on whether the space has
    /// scrolled before (#239): `center`/`start`/`end` compute a
    /// fixed resting position on *every* focus, then clamp it to
    /// keep the focused slot fully visible. `follow` instead keeps
    /// `previous` and pans the minimum needed to reveal the
    /// focused slot (#66) — the only anchor that reads `previous`;
    /// a `follow` space that has never scrolled seeds at the row
    /// start (`previous ?? visibleMin`). When `focusedPos` is nil
    /// (a floating window, or nothing focused) there is no slot to
    /// place, so the viewport holds its previous offset (#141).
    /// The result is finally clamped so the row never reveals
    /// empty margin past its ends.
    ///
    /// Public because the Settings preview asks it for the same
    /// resting position it draws (#776): the schematic's anchor
    /// arms re-implemented this switch without the clamps and
    /// drew a leading margin the engine cannot produce.
    public static func offset(
        anchor: ScrollingParams.Anchor,
        previous: CGFloat?,
        along: CGFloat,
        size: CGFloat,
        rowLength: CGFloat,
        focusedPos: CGFloat?
    ) -> CGFloat {
        var target: CGFloat
        if let focusedPos {
            // The range of offsets that keep the focused slot
            // fully inside the viewport: sliding it any further
            // would clip its leading or trailing edge.
            let visibleMin = -focusedPos
            let visibleMax = along - size - focusedPos
            switch anchor {
            case .follow:
                // Scroll-into-view (#66): hold the prior offset,
                // pan only enough to reveal the focused slot. A
                // never-scrolled space seeds at the row start.
                let base = previous ?? visibleMin
                target = min(max(base, visibleMin), visibleMax)
            case .center, .start, .end:
                // Fixed resting position, recomputed every focus.
                let resting = anchorOffset(
                    anchor: anchor,
                    along: along,
                    size: size,
                    focusedPos: focusedPos
                )
                target = min(max(resting, visibleMin), visibleMax)
            }
        } else {
            // The focused window has no slot in the row (a
            // floating window, or nothing focused): there is
            // nothing to scroll into view, so the viewport
            // stays put instead of snapping home (#141).
            target = previous ?? 0
        }

        // Boundary awareness: never reveal empty margin past the
        // row ends.
        guard rowLength > along else { return 0 }
        return min(max(target, along - rowLength), 0)
    }

    /// A fixed anchor's resting offset for a focused slot, before
    /// visibility/boundary clamping. `start`/`end` are
    /// axis-relative: the `along` coordinate already runs along
    /// the scroll axis (x horizontal, y vertical), so `start` is
    /// the leading edge (left / top) and `end` the trailing edge
    /// (right / bottom) on both orientations — no per-axis branch.
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
            // Unreachable: `follow` is resolved from `previous`
            // in `offset`, never as a fixed resting position.
            return -focusedPos
        }
    }
}
