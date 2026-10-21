import CoreGraphics

/// One edge a bar sits on, each bar's own visibility there (#761)
/// and which of them the layout gives a strip up for (#1524).
/// Shown and reserved are apart so a bar may draw over the
/// windows; on an edge two bars share — one fused shelf, one strip
/// — the edge reserves at the depth its most present RESERVING bar
/// asks: the full strip for `always`, the sliver
/// (`KiwiShelf.hiddenReservation`) for `auto`, nothing for
/// `hidden`. A reveal is an overlay.
public struct ShelfEdge: Sendable, Equatable {
    public let edge: AppBarEdge
    /// Each bar on this edge and its stored visibility.
    public var bars: [ShelfBar: ShelfVisibility]
    /// The bars on this edge whose `reserve` is on.
    public var reserving: Set<ShelfBar>

    public init(
        _ edge: AppBarEdge,
        reserves: Bool,
        bars: [ShelfBar: ShelfVisibility] = [:]
    ) {
        self.edge = edge
        self.bars = bars
        self.reserving = reserves ? Set(bars.keys) : []
    }

    /// Adds `bar` at `visibility`, reserving where `reserves`.
    mutating func add(
        _ bar: ShelfBar,
        _ visibility: ShelfVisibility,
        reserves: Bool
    ) {
        bars[bar] = visibility
        if reserves { reserving.insert(bar) }
    }

    /// What the edge reserves for: its most present reserving
    /// bar as it reads on this edge (`shown`), nil where no bar
    /// reserves — an `auto` bar beside an `always` one never asks
    /// for a sliver on an edge that does not hide.
    public var reservation: ShelfVisibility? {
        reserving.compactMap { shown($0) }
            .max { $0.presence < $1.presence }
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

    /// Whether the edge draws nothing at rest, so a bar a reveal
    /// shows comes onto an empty edge and takes the reveal's own
    /// motion — Hidden as well as Auto — where one shown beside an
    /// always sibling joins it (#2497).
    public var drawsNothingAtRest: Bool { drawnAtRest.isEmpty }
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
