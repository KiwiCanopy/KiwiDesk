import CoreGraphics

/// The KiwiShelf's screen strip and the layout bounds it leaves
/// (#293, #1517): ONE reservation for both bars, taken in every
/// layout whenever a bar can show, so a layout switch never
/// reflows windows.
public enum ShelfGeometry {
    // Layout span flows must route via TilingSettings.layoutBounds(from:)
    // (#537, LayoutBoundsRoutingTests).

    /// The strip the shelf occupies on visible bounds — its outer
    /// margin in from the screen edge (#1516). The bars take
    /// their segments inside it (`ShelfArrangement`).
    public static func strip(
        in visible: CGRect,
        shelf: KiwiShelf
    ) -> CGRect {
        AppBarGeometry.barFrame(
            in: visible,
            edge: shelf.edge,
            thickness: shelf.thickness,
            outer: shelf.outerMargin
        )
    }

    /// Visible bounds minus the shelf's whole reservation — outer
    /// margin, strip and inner margin — handed to layout context;
    /// the windows' own outer gap applies to what remains.
    public static func remainingFrame(
        in visible: CGRect,
        shelf: KiwiShelf
    ) -> CGRect {
        AppBarGeometry.remaining(
            visible,
            edge: shelf.edge,
            reserving: shelf.reservation
        )
    }
}
