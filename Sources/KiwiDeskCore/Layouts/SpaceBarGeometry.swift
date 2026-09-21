import CoreGraphics

/// Space Bar screen strip reservation and layout bounds arithmetic (#293).
public enum SpaceBarGeometry {
    // Layout span flows must route via TilingSettings.layoutBounds(from:)
    // (#537, LayoutBoundsRoutingTests).

    /// The strip the bar occupies on visible bounds — its outer
    /// margin in from the screen edge (#1516) — or nil when
    /// disabled.
    public static func strip(
        in visible: CGRect,
        style: SpaceBarStyle
    ) -> CGRect? {
        guard style.enabled else { return nil }
        return AppBarGeometry.barFrame(
            in: visible,
            edge: style.edge,
            thickness: style.thickness,
            outer: style.outerMargin
        )
    }

    /// Visible bounds minus the bar's whole reservation — outer
    /// margin, strip and inner margin — handed to layout context;
    /// the windows' own outer gap applies to what remains.
    public static func remainingFrame(
        in visible: CGRect,
        style: SpaceBarStyle
    ) -> CGRect {
        guard style.enabled else { return visible }
        return AppBarGeometry.remaining(
            visible,
            edge: style.edge,
            reserving: style.reservation
        )
    }
}
