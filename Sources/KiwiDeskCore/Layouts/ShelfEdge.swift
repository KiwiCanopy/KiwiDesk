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
