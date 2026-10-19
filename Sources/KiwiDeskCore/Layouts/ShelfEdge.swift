import CoreGraphics

/// One edge a bar sits on, whether the layout gives its strip up
/// (#1524) and each bar's own visibility there (#761). Shown and
/// reserved are apart so a bar may draw over the windows; on an
/// edge two bars share — one fused shelf, one strip — the edge
/// reserves while EITHER bar does, at the depth its most present
/// bar asks: the full strip for `always`, the sliver
/// (`KiwiShelf.hiddenReservation`) for `auto`, nothing for
/// `hidden`. A reveal is an overlay.
public struct ShelfEdge: Sendable, Equatable {
    public let edge: AppBarEdge
    public var reserves: Bool
    /// Each bar on this edge and its stored visibility.
    public var bars: [ShelfBar: ShelfVisibility]

    public init(
        _ edge: AppBarEdge,
        reserves: Bool,
        bars: [ShelfBar: ShelfVisibility] = [:]
    ) {
        self.edge = edge
        self.reserves = reserves
        self.bars = bars
    }

    /// The edge's visibility: its most present bar's.
    public var visibility: ShelfVisibility {
        bars.values.max { $0.presence < $1.presence } ?? .hidden
    }

    /// Whether the edge hides to a mark and reserves its sliver.
    public var hides: Bool { visibility == .auto }

    /// What `bar` reads on this edge: an `auto` bar beside an
    /// `always` one reads `always` — hiding inside a strip already
    /// paid for saves nothing — and `hidden` stays hidden.
    public func shown(_ bar: ShelfBar) -> ShelfVisibility? {
        guard let own = bars[bar] else { return nil }
        return own == .auto && visibility == .always ? .always : own
    }

    /// The bars an edge draws at rest, before any reveal.
    public var drawnAtRest: Set<ShelfBar> {
        Set(bars.keys.filter { shown($0) == .always })
    }
}

/// What the shelves take off a screen in one layout: the edges
/// it reserves at the shelf's depth, the hiding edges it reserves
/// at the sliver's (#761), and each depth — the whole input
/// `TilingSettings.layoutBounds(from:mode:on:)` reads, so two equal
/// values leave every layout's bounds alone (#1524).
public struct ShelfReservation: Sendable, Equatable {
    public let edges: [AppBarEdge]
    public let depth: CGFloat
    public var hiding: [AppBarEdge] = []
    public var hidingDepth: CGFloat = 0

    /// `visible` minus each edge's reservation.
    public func remaining(in visible: CGRect) -> CGRect {
        let full = edges.reduce(visible) { frame, edge in
            AppBarGeometry.remaining(
                frame,
                edge: edge,
                reserving: depth
            )
        }
        return hiding.reduce(full) { frame, edge in
            AppBarGeometry.remaining(
                frame,
                edge: edge,
                reserving: hidingDepth
            )
        }
    }
}
