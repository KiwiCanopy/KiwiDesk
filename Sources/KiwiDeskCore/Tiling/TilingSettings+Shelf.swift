import CoreGraphics
import Foundation

/// The edges the shown bars sit on and what the layouts reserve
/// for them (#1517, #1524, #1731), each answered per screen
/// (#1948). Split from `TilingSettings+Resolution.swift`.
extension TilingSettings {
    /// Whether the KiwiShelf carries any bar in some layout — the
    /// Space Bar or any layout's App Bar is on. The Settings gates
    /// ask it; the reservation asks `shelfEdges(in:on:)`.
    public var shelfShows: Bool {
        spaceBarStyle.enabled || anyAppBarCanShow
    }

    /// Whether either bar gives some screen an edge of its own.
    public var hasScreenEdges: Bool {
        !spaceBarStyle.edgeOverride.isEmpty
            || !appBarStyle.edgeOverride.isEmpty
    }

    /// These settings as `screen` (a `Display.fingerprint`) shows
    /// them: each bar's `edge` resolved for that screen — its own
    /// where it has one, else the bar's (#1948). The ONE
    /// per-screen step, taken before `barEdges(space:app:)` folds
    /// the edges, so the reservation and the live plan read one
    /// answer; nil keeps each bar's own edge. The copy holds no
    /// entry, so resolving it again changes nothing.
    public func onScreen(_ screen: String?) -> TilingSettings {
        guard hasScreenEdges else { return self }
        var out = self
        out.spaceBarStyle.setEdge(spaceBarStyle.edge(on: screen))
        out.appBarStyle.setEdge(appBarStyle.edge(on: screen))
        return out
    }

    /// The edges a space laid out in `mode` on `screen` reserves —
    /// of the edges `barEdges` lists for the Space Bar, which draws
    /// in every layout, and that layout's own App Bar where it is
    /// on (#1517, #1731), the ones that reserve (#1524). A layout
    /// that draws no bar keeps the whole screen; the price is that
    /// a switch into a layout whose App Bar draws on an edge
    /// nothing else holds moves windows by the strip.
    public func shelfEdges(
        in mode: LayoutMode,
        on screen: String?
    ) -> [AppBarEdge] {
        onScreen(screen).barEdges(
            space: spaceBarStyle.enabled,
            app: appBarHost(for: mode)?.appBar.enabled == true
        ).filter(\.reserves).map(\.edge)
    }

    /// The edges the shown bars sit on — the ONE list the
    /// reservation and the live plan both take, over settings
    /// already resolved for a screen (`onScreen(_:)`): the Space
    /// Bar's first, then the App Bar's unless the two share it, so
    /// two bars are never stacked on one edge
    /// (`ShelfSplitGeometryTests` ▸ `edgesPerMode`) and
    /// `ShelfGeometry.strips` measures the Space Bar's whole edge.
    /// A shared edge reserves while either bar on it does — the
    /// fold is here, at the dedup, and nowhere beside it
    /// (`BarReserveTests`, #1524).
    public func barEdges(space: Bool, app: Bool) -> [ShelfEdge] {
        var edges: [ShelfEdge] = []
        if space {
            edges.append(
                ShelfEdge(
                    spaceBarStyle.edge,
                    reserves: spaceBarStyle.reserve
                )
            )
        }
        guard app else { return edges }
        if let shared = edges.firstIndex(where: {
            $0.edge == appBarStyle.edge
        }) {
            edges[shared].reserves =
                edges[shared].reserves || appBarStyle.reserve
        } else {
            edges.append(
                ShelfEdge(
                    appBarStyle.edge,
                    reserves: appBarStyle.reserve
                )
            )
        }
        return edges
    }

    /// The edge both bars sit on while they share one — one fused
    /// shelf — or nil while they are split, a bar per edge (#1731).
    /// The one comparison of the bars' own edges; the Position
    /// master asks `uniformBarEdge`, which adds the screens.
    public var sharedBarEdge: AppBarEdge? {
        spaceBarStyle.edge == appBarStyle.edge
            ? spaceBarStyle.edge : nil
    }

    /// The edge both bars sit on on EVERY screen — what Settings'
    /// Position master selects — or nil while the bars differ or
    /// a screen draws an edge of its own (`ScreenEdged.screensDiffer`,
    /// #1948): a level whose lower levels disagree shows none.
    public var uniformBarEdge: AppBarEdge? {
        guard !spaceBarStyle.screensDiffer,
            !appBarStyle.screensDiffer
        else { return nil }
        return sharedBarEdge
    }

    /// Insets visible bounds by the reservation of every edge a
    /// bar draws on in `mode` on `screen` (#293, #1517, #1731,
    /// #1948). Deliberately NOT public: it takes a raw frame the
    /// caller obtained some other way — the unsafe half. Callers
    /// with a screen want `TilingEngine.layoutBounds(on:)` (#537),
    /// and the routing guards scan only this module, so a
    /// cross-module caller would be invisible to them.
    func layoutBounds(
        from visible: CGRect,
        mode: LayoutMode,
        on screen: String?
    ) -> CGRect {
        shelfReservation(in: mode, on: screen).remaining(in: visible)
    }

    /// The whole input `layoutBounds(from:mode:on:)` reads for
    /// `mode` on `screen` — what a bar write must change to owe a
    /// pass (#1524, `BarReserveCoreTests` ▸
    /// `unchangedReservationSkipsTheRetile`).
    public func shelfReservation(
        in mode: LayoutMode,
        on screen: String?
    ) -> ShelfReservation {
        ShelfReservation(
            edges: shelfEdges(in: mode, on: screen),
            depth: kiwishelf.reservation
        )
    }
}
