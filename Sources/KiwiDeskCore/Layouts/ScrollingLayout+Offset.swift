import CoreGraphics

/// The viewport-offset half of `ScrollingLayout`, split at the
/// file ceiling: the anchor dispatch and the clamps that keep a
/// row from revealing empty margin past its ends. Pure maths —
/// `calculateGeometry` and `viewportRest` (in
/// `ScrollingLayout+Viewport`) both resolve through it, and so
/// does the Settings preview (#776).
extension ScrollingLayout {
    /// The viewport offset for `focus` at `focusedPos`, given the
    /// rest from the last tile (`previous`).
    ///
    /// Dispatches on `anchor`, not on whether the space has
    /// scrolled before (#239): `center`/`start`/`end` compute a
    /// fixed resting position on *every* focus, then clamp it to
    /// keep the focused slot fully visible. `follow` instead pans
    /// the minimum needed to reveal the focused slot from where
    /// the viewport already was (#66) — the only anchor that
    /// reads `previous`; a `follow` space that has never scrolled
    /// seeds at the row start. When `focusedPos` is nil (a
    /// floating window, or nothing focused) there is no slot to
    /// place, so the viewport holds its previous offset (#141).
    /// The result is finally clamped so the row never reveals
    /// empty margin past its ends.
    ///
    /// "Where the viewport already was" is the half `follow` has
    /// to read carefully, which is why `previous` carries the
    /// slot it was measured against (#966): see `heldBase`.
    ///
    /// Public because the Settings preview asks it for the same
    /// resting position it draws (#776): the schematic's anchor
    /// arms re-implemented this switch without the clamps and
    /// drew a leading margin the engine cannot produce.
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
            // The range of offsets that keep the focused slot
            // fully inside the viewport: sliding it any further
            // would clip its leading or trailing edge.
            let visibleMin = -focusedPos
            let visibleMax = along - size - focusedPos
            switch anchor {
            case .follow:
                // Scroll-into-view (#66): hold where the viewport
                // was, pan only enough to reveal the focused
                // slot. A never-scrolled space seeds at the row
                // start.
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
            target = previous?.offset ?? 0
        }

        // Boundary awareness: never reveal empty margin past the
        // row ends.
        guard rowLength > along else { return 0 }
        return min(max(target, along - rowLength), 0)
    }

    /// The offset `follow` pans from — nil for a space that has
    /// never scrolled, which seeds at the row start instead.
    ///
    /// Two things can put the focused slot somewhere new, and
    /// `follow` owes them opposite answers (#966):
    ///
    /// - **The focus moved.** Nothing else changed, so holding
    ///   the recorded offset is exactly what makes the pan read
    ///   as scroll-into-view: the side you came from stays open
    ///   (#66).
    /// - **Every slot moved underneath an unchanged focus** — a
    ///   slot resize (one size serves the whole row, so a resize
    ///   re-positions every slot), a `swap` that re-seats the
    ///   focus in the array, a neighbour opening or closing ahead
    ///   of it, a #677 bound re-packing the row. Here the
    ///   recorded offset points at a different place than it did
    ///   when it was recorded, and holding it slides the window
    ///   the user is acting on toward the leading edge. Shift it
    ///   by however far the slot moved instead, so that slot
    ///   keeps its place on screen and the row rearranges around
    ///   it — except where the slot was resting flush against
    ///   the trailing border, where the edge is what it keeps.
    ///   Otherwise a shrink tears the slot off a border it was
    ///   sitting on and opens a gap the row then fills from
    ///   behind, which is the one shape that reads as broken
    ///   rather than merely different (device QA, 2026-08-27).
    ///   A slot that is last in its row already behaved this
    ///   way, because the boundary clamp refuses to reveal
    ///   margin past the row end — so this is also what stops
    ///   two identical-looking situations answering
    ///   differently.
    ///
    /// The recorded slot is what tells them apart: it names the
    /// focus the offset was measured against and where that slot
    /// sat at the time. No slot recorded — a hand-seeded rest, or
    /// a space that has never placed one — reads as the first
    /// case. A pass that places no slot does not produce that
    /// state: it carries the previous measurement through with
    /// the offset it is also carrying (`ScrollRest`).
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
        // Resting against the TRAILING border: hold that edge,
        // so the slot gives its space back on the side that is
        // open rather than tearing away from the border with a
        // hidden neighbour behind it. The verdict was reached
        // when the offset was measured (`ScrollRest.Slot`), so
        // a slot that filled the viewport already reads
        // `.leading` and falls through — the precedence is not
        // re-decided here.
        //
        // The value returned is the visibility clamp's own upper
        // bound, which is what "flush at the trailing edge"
        // means in offsets; the clamp below therefore keeps it
        // unchanged rather than fighting it.
        if slot.restingOn == .trailing {
            return along - focusedSpan - focusedPos
        }
        return previous.offset + (slot.position - focusedPos)
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
