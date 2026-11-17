import Foundation

/// The pocket's edge per screen (#3376), on the bars' `ScreenEdged`
/// doors (#1948): `kiwishelf.pocket_edge` and its sparse
/// `pocket_edge_override`, keyed by `Display.fingerprint`.
public struct PocketEdges: ScreenEdged, Equatable, Sendable {
    public var edge: AppBarEdge
    public var edgeOverride: [String: AppBarEdge]
}

extension KiwiShelf {
    /// The pocket's edge and its screens' own, as one `ScreenEdged`
    /// value. Write the pocket's edge only through its doors:
    /// `shelf.pocketEdges.setEdge(_:)` for every screen,
    /// `setEdge(_:on:among:)` for one (`PocketEdgeCensusTests`).
    public var pocketEdges: PocketEdges {
        get { PocketEdges(edge: pocketEdge, edgeOverride: pocketEdgeOverride) }
        set {
            pocketEdge = newValue.edge
            pocketEdgeOverride = newValue.edgeOverride
        }
    }

    /// This shelf as `screen` (a fingerprint) shows it: the
    /// pocket's edge resolved for that screen, no entry left. Nil
    /// keeps the pocket's own edge.
    public func onScreen(_ screen: String?) -> KiwiShelf {
        guard !pocketEdgeOverride.isEmpty else { return self }
        var out = self
        out.pocketEdges.setEdge(pocketEdges.edge(on: screen))
        return out
    }
}
