import CoreGraphics

/// One edge a shown bar sits on, whether the layout gives its
/// strip up (#1524) and whether its shelf hides (#761). Shown and
/// reserved are apart so a bar may draw over the windows; on an
/// edge two bars share — one fused shelf, one strip — the edge
/// reserves while EITHER bar does and hides only while BOTH do.
/// A hiding edge reserves nothing: a reveal is an overlay.
public struct ShelfEdge: Sendable, Equatable {
    public let edge: AppBarEdge
    public var reserves: Bool
    public var hides: Bool

    public init(_ edge: AppBarEdge, reserves: Bool, hides: Bool = false) {
        self.edge = edge
        self.reserves = reserves
        self.hides = hides
    }
}

/// What the shelves take off a screen in one layout: the edges
/// it reserves and each edge's depth — the whole input
/// `TilingSettings.layoutBounds(from:mode:on:)` reads, so two equal
/// values leave every layout's bounds alone (#1524).
public struct ShelfReservation: Sendable, Equatable {
    public let edges: [AppBarEdge]
    public let depth: CGFloat

    /// `visible` minus each edge's reservation.
    public func remaining(in visible: CGRect) -> CGRect {
        edges.reduce(visible) { frame, edge in
            AppBarGeometry.remaining(
                frame,
                edge: edge,
                reserving: depth
            )
        }
    }
}
