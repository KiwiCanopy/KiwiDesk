import CoreGraphics

/// Space Bar screen strip reservation and layout bounds arithmetic (#293).
public enum SpaceBarGeometry {
    // Layout span flows must route via TilingSettings.layoutBounds(from:)
    // (#537, LayoutBoundsRoutingTests).

    /// The strip the bar occupies on visible bounds, or nil when disabled.
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

    /// Visible bounds minus Space Bar strip handed to layout context.
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
