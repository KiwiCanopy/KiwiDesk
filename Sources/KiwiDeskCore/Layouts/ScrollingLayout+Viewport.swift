import CoreGraphics

/// The read-back half of `ScrollingLayout`, split at the file
/// ceiling: what a caller asks the layout ABOUT a row without
/// materializing its frames. Where either answer needs the row's
/// geometry it derives it from the same `metrics` the frames come
/// from, so the two can never disagree about one row — both also
/// answer a short row without asking for geometry at all.
///
/// Neither promises that `windows` is the array
/// `calculateGeometry` was handed; it is a free parameter here.
/// `TilingEngine.layoutInput` is what holds the frames, the
/// persisted rest and the z-order arm to one reading of the
/// space.
extension ScrollingLayout {
    /// The viewport rest `calculateGeometry` would compute for
    /// `windows`, without materializing frames (#66). Lets the
    /// caller read back the value to persist as the next tile's
    /// `Space.scrollRest`, so a focus-driven retile can restore
    /// the "previous offset" input without KiwiCore re-deriving
    /// the anchor/clamp math itself. The offset travels with the
    /// slot it was measured against, which is what `follow` reads
    /// to tell a focus change from a row that moved underneath an
    /// unchanged focus (#966) — recorded fresh on a pass that
    /// placed a slot, and carried through unchanged on a pass
    /// that placed none, where the offset itself is carried too.
    ///
    /// A lone window fills the whole area, so `calculateGeometry`
    /// ignores the offset for it — but this must still *preserve*
    /// it, not persist 0 (#155): float one of two scrolled
    /// windows and the row drops to a single tiled window; a 0
    /// here overwrites the saved offset, so unfloating rebuilds
    /// the row from home. Returning the prior rest whole keeps
    /// the viewport where it was.
    static func viewportRest(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> ScrollRest {
        guard windows.count > 1 else {
            return context.scrollRest ?? ScrollRest(offset: 0)
        }
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.axisIsHorizontal
        let metrics = metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        let value = offset(
            anchor: context.scrolling.anchor,
            previous: context.scrollRest,
            focus: context.focused,
            along: metrics.along,
            size: metrics.focusedSpan,
            rowLength: metrics.rowLength,
            focusedPos: metrics.focusedPos
        )
        guard let focus = context.focused,
            let position = metrics.focusedPos
        else {
            // No slot placed this pass (a floating focus, or
            // nothing focused): `offset` carried the previous
            // offset through (#141), so its provenance carries
            // with it — the same call the `count > 1` arm makes
            // above. Destroying a measurement that still
            // describes the offset being returned would hand the
            // next pan a rest that reads as a focus change, and
            // #966's drift would come back the moment the row
            // changed while a float held focus.
            return ScrollRest(
                offset: value,
                slot: context.scrollRest?.slot
            )
        }
        return ScrollRest(
            offset: value,
            focus: focus,
            position: position
        )
    }

    /// Whether the row is longer than the viewport, so slots pile
    /// up at the edges and their stacking matters (#150). A row
    /// that fits entirely shows no overlap, so a swap within it
    /// cannot scramble the edge piles' z-order — there is nothing
    /// to restore. A superset of "the swapped pair touches a
    /// pile": the focus that moved in a swap is always panned
    /// fully into view, so a per-slot test would gate on the
    /// other window's transient position; the overflow test is
    /// cheaper and never misses a real scramble.
    static func rowOverflows(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> Bool {
        guard windows.count > 1 else { return false }
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.axisIsHorizontal
        let m = metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        return m.rowLength > m.along
    }
}
