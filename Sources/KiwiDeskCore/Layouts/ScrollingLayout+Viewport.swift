import CoreGraphics

/// Viewport rest calculations and geometry queries for `ScrollingLayout`
/// (`TilingEngine.layoutInput`).
extension ScrollingLayout {
    /// Computes viewport rest for `windows` without materializing frames
    /// (#66, #155, #966).
    /// Preserves existing offset for single-window spaces and floating focus
    /// (#141).
    static func viewportRest(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> ScrollRest {
        // A lone window that fills has no rest to measure and
        // keeps the history for a second arrival (#141); one kept
        // at its slot (#1389) rests like any row.
        guard windows.count > 1 || !context.scrolling.fillWhenAlone
        else {
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
        guard let focus = metrics.subject,
            let position = metrics.focusedPos
        else {
            return ScrollRest(
                offset: value,
                slot: context.scrollRest?.slot
            )
        }
        return ScrollRest(
            offset: value,
            focus: focus,
            position: position,
            restingOn: border(
                lead: value + position,
                span: metrics.focusedSpan,
                along: metrics.along
            )
        )
    }

    /// Evaluates which viewport border a slot rests against
    /// (#966). Leading is tested first as a RULING: a slot flush
    /// at both borders records `.leading` — the reader's eye
    /// anchors at the leading edge.
    static func border(
        lead: CGFloat,
        span: CGFloat,
        along: CGFloat
    ) -> ScrollRest.Border? {
        if abs(lead) <= edgeTolerance { return .leading }
        if abs(lead + span - along) <= edgeTolerance {
            return .trailing
        }
        return nil
    }

    /// Border-flush tolerance. Every compared value is the
    /// layout's own ideal geometry, so this absorbs accumulated
    /// rounding and nothing wider — a slot a VISIBLE distance from
    /// the edge must not read as flush.
    static let edgeTolerance: CGFloat = 0.5

    /// Whether the row reaches past the viewport along the scroll
    /// axis (#150) — so an edge pin piles a slot behind or over a
    /// neighbour. Judged on the DRAWN offset, not the row length
    /// alone: a fixed anchor rests the focus where it says and a
    /// row shorter than the axis can still hang off an edge
    /// (#1388); `follow`'s clamp makes the two readings agree.
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
        let value = offset(
            anchor: context.scrolling.anchor,
            previous: context.scrollRest,
            focus: context.focused,
            along: m.along,
            size: m.focusedSpan,
            rowLength: m.rowLength,
            focusedPos: m.focusedPos
        )
        return value < -edgeTolerance
            || value + m.rowLength > m.along + edgeTolerance
    }
}
