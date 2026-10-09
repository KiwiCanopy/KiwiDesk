import CoreGraphics

/// The shelves' screen strips and the layout bounds they leave
/// (#293, #1517, #1731): a strip per edge a bar takes — one while
/// the bars share an edge, two while they are split — each taken
/// in every layout where a bar draws on it.
public enum ShelfGeometry {
    // Layout span flows must route via
    // TilingSettings.layoutBounds(from:mode:on:)
    // (#537, LayoutBoundsRoutingTests).

    /// The strip on `edge` of visible bounds — the outer margin in
    /// from the screen edge (#1516). The bars take their segments
    /// inside it (`ShelfArrangement`).
    public static func strip(
        in visible: CGRect,
        edge: AppBarEdge,
        shelf: KiwiShelf
    ) -> CGRect {
        AppBarGeometry.barFrame(
            in: visible,
            edge: edge,
            thickness: shelf.thickness,
            outer: shelf.outerMargin
        )
    }

    /// The strip of each of `edges`, in order: each is measured on
    /// what the edges before it leave, so at a corner the earlier
    /// strip runs the whole edge and the later one stops at its
    /// reservation. Callers list the Space Bar's edge first — it
    /// draws in every layout, so it never moves for the App Bar,
    /// which yields at a corner as it did before #1517.
    public static func strips(
        in visible: CGRect,
        edges: [AppBarEdge],
        shelf: KiwiShelf
    ) -> [CGRect] {
        edges.indices.map { index in
            strip(
                in: remainingFrame(
                    in: visible,
                    edges: Array(edges[..<index]),
                    shelf: shelf
                ),
                edge: edges[index],
                shelf: shelf
            )
        }
    }

    /// Visible bounds minus each edge's whole reservation — outer
    /// margin, strip and inner margin — handed to layout context;
    /// the windows' own outer gap applies to what remains.
    public static func remainingFrame(
        in visible: CGRect,
        edges: [AppBarEdge],
        shelf: KiwiShelf
    ) -> CGRect {
        ShelfReservation(edges: edges, depth: shelf.reservation)
            .remaining(in: visible)
    }
}
