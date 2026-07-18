import CoreGraphics

/// Space-first reservation (#293): the Space Bar's strip is
/// carved from the display's *original* visible frame, and the
/// remainder becomes the `bounds` every layout — and the App
/// Bar's own reservation — operates inside. Layouts never learn
/// the Space Bar exists, which is what makes every stacking rule
/// fall out for free:
///
/// - Same edge as the App Bar: the App Bar carves its strip from
///   the already-inset frame, so the Space Bar sits
///   screen-facing, the App Bar window-facing, and the combined
///   inset is the sum of both strips.
/// - Perpendicular edges: the App Bar's strip spans the inset
///   frame, so it starts inside the Space Bar's inset and the
///   corners cannot overlap.
public enum SpaceBarGeometry {
    // NOTE: every `axVisibleFrame -> settings.context(bounds:)`
    // flow MUST route its bounds through
    // `TilingSettings.layoutBounds(from:)` (which wraps
    // `remainingFrame`) — a flow that skips it re-opens the
    // strip to layouts.

    /// The strip the bar occupies on `visible` (AX coordinates),
    /// or nil while the bar is off. Reuses the App Bar's
    /// edge-generic carve so the two bars can't disagree about
    /// what an edge means.
    public static func strip(
        in visible: CGRect,
        style: SpaceBarStyle
    ) -> CGRect? {
        guard style.enabled else { return nil }
        return AppBarGeometry.barFrame(
            in: visible,
            edge: style.edge,
            thickness: style.thickness
        )
    }

    /// `visible` minus the bar's strip — the bounds handed to
    /// `TilingSettings.context(bounds:space:)`. The full frame
    /// while the bar is off (a disabled bar reserves nothing).
    /// No inner gap here: the layout's own outer gap applies
    /// inside the remaining frame.
    public static func remainingFrame(
        in visible: CGRect,
        style: SpaceBarStyle
    ) -> CGRect {
        guard let strip = strip(in: visible, style: style)
        else { return visible }
        var frame = visible
        switch style.edge {
        case .top:
            frame.origin.y += strip.height
            frame.size.height =
                max(visible.height - strip.height, 0)
        case .bottom:
            frame.size.height =
                max(visible.height - strip.height, 0)
        case .left:
            frame.origin.x += strip.width
            frame.size.width =
                max(visible.width - strip.width, 0)
        case .right:
            frame.size.width =
                max(visible.width - strip.width, 0)
        }
        return frame
    }
}
