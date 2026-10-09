import CoreGraphics

/// One edge a shown bar sits on, and whether the layout gives its
/// strip up (#1524). Shown and reserved are apart so a bar may
/// draw over the windows; on an edge two bars share — one fused
/// shelf, one strip — the edge reserves while EITHER bar does.
public struct ShelfEdge: Sendable, Equatable {
    public let edge: AppBarEdge
    public var reserves: Bool

    public init(_ edge: AppBarEdge, reserves: Bool) {
        self.edge = edge
        self.reserves = reserves
    }
}

/// What the shelves take off a screen in one layout: the edges
/// it reserves and each edge's depth — the whole input
/// `TilingSettings.layoutBounds(from:mode:)` reads, so two equal
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
