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

    /// Evaluates if slot rests against leading or trailing viewport border
    /// (#966).
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

    /// Floating-point tolerance for border flush detection (0.5 pt).
    static let edgeTolerance: CGFloat = 0.5

    /// Checks if total row length exceeds viewport along the scrolling axis
    /// (#150).
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
