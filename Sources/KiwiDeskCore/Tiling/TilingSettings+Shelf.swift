import CoreGraphics
import Foundation

/// The edges the shown bars sit on and what the layouts reserve
/// for them (#1517, #1524, #1731), each answered per screen
/// (#1948). Split from `TilingSettings+Resolution.swift`.
extension TilingSettings {
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

    /// The App Bar's visibility in `mode` (#761) — its layout's
    /// own value, or nil where the layout carries no App Bar.
    public func appBarVisibility(in mode: LayoutMode) -> ShelfVisibility? {
        appBarHost(for: mode)?.appBar.visibility
    }

    /// The visibility every bar shares — the Space Bar's and each
    /// hosting layout's App Bar — or nil while they differ: what
    /// Settings' Show master selects (#761).
    public var uniformBarVisibility: ShelfVisibility? {
        let all = [spaceBarStyle.visibility] + appBarHosts.map(\.visibility)
        return Set(all).count == 1 ? all.first : nil
    }

    /// Sets every bar's own visibility at once — each still stored
    /// per bar and per layout, nothing linked (#761).
    public mutating func setEveryBarVisibility(_ visibility: ShelfVisibility) {
        spaceBarStyle.visibility = visibility
        for mode in LayoutMode.allCases {
            setAppBarVisibility(visibility, in: mode)
        }
    }

    /// `mode`'s App Bar visibility, where the mode hosts one —
    /// through the one `appBarPath(for:)`.
    public mutating func setAppBarVisibility(
        _ visibility: ShelfVisibility,
        in mode: LayoutMode
    ) {
        guard let path = Self.appBarPath(for: mode) else { return }
        self[keyPath: path].visibility = visibility
    }

    /// Whether `bar`'s shortcut can show it in `mode` (#761): the
    /// bar is not `always` — and, for the App Bar, the layout
    /// carries one. The verb's own gate (`shelfRevealCommand`); a
    /// bar set to `always` refuses with a pill.
    public func revealActionLive(
        _ bar: ShelfBar,
        in mode: LayoutMode
    ) -> Bool {
        switch bar {
        case .space: spaceBarStyle.visibility.revealable
        case .app: appBarVisibility(in: mode)?.revealable == true
        }
    }

    /// Whether `bar`'s shortcut can show it in SOME layout — what
    /// a Settings shortcut row asks to grey (#761).
    public func revealActionLiveAnywhere(_ bar: ShelfBar) -> Bool {
        LayoutMode.allCases.contains { revealActionLive(bar, in: $0) }
    }

    /// Whether some bar ever hides, so a reveal can play — what
    /// Settings' Reveal row asks to grey (owner ruling,
    /// 2026-10-21): Hidden in some layout, or Auto where no Always
    /// sibling keeps it shown on some screen (`autoReadsAlways`).
    public var someBarHides: Bool {
        let hides = {
            (screen: TilingSettings, bar: ShelfBar, mode: LayoutMode)
                -> Bool in
            let value =
                bar == .space
                ? screen.spaceBarStyle.visibility
                : screen.appBarVisibility(in: mode)
            switch value {
            case .hidden: return true
            case .auto: return !screen.autoReadsAlways(bar, in: mode, on: nil)
            case .always, nil: return false
            }
        }
        return screenVariants.contains { screen in
            LayoutMode.allCases.contains { mode in
                hides(screen, .space, mode) || hides(screen, .app, mode)
            }
        }
    }

    /// These settings as each screen they can draw on shows them
    /// (#1948): the bars' own edges, then every screen with an edge
    /// of its own. A reader asking whether a setting acts on SOME
    /// screen asks each; the set errs toward "acts", never toward
    /// a wrong grey.
    public var screenVariants: [TilingSettings] {
        let screens = Set(spaceBarStyle.edgeOverride.keys)
            .union(appBarStyle.edgeOverride.keys)
        return [onScreen(nil)] + screens.sorted().map { onScreen($0) }
    }

    /// The edges a space laid out in `mode` on `screen` reserves
    /// in full — of the edges `barEdges` lists for the Space Bar,
    /// which sits in every layout, and that layout's own App Bar
    /// (#1517, #1731), the ones that reserve (#1524) and read
    /// `always` (#761). A layout whose bars are hidden keeps the
    /// whole screen; the price is that a switch into a layout whose
    /// App Bar is shown on an edge nothing else holds moves windows
    /// by the strip.
    public func shelfEdges(
        in mode: LayoutMode,
        on screen: String?
    ) -> [AppBarEdge] {
        onScreen(screen).barEdges(
            space: spaceBarStyle.visibility,
            app: appBarVisibility(in: mode)
        ).filter { $0.reservation == .always }.map(\.edge)
    }

    /// The hiding edges a space laid out in `mode` on `screen`
    /// reserves its sliver on (#761) — `shelfEdges`' twin over the
    /// same fold, apart because a float stays out of a full strip
    /// and never a sliver.
    public func hidingEdges(
        in mode: LayoutMode,
        on screen: String?
    ) -> [AppBarEdge] {
        onScreen(screen).barEdges(
            space: spaceBarStyle.visibility,
            app: appBarVisibility(in: mode)
        ).filter { $0.reservation == .auto }.map(\.edge)
    }

    /// Whether `bar`, stored `auto`, reads `always` in `mode` on
    /// `screen` — beside an `always` bar on its edge (#761), which
    /// keeps it shown: the note Settings draws under its row, and
    /// why its shortcut refuses.
    public func autoReadsAlways(
        _ bar: ShelfBar,
        in mode: LayoutMode,
        on screen: String?
    ) -> Bool {
        onScreen(screen).barEdges(
            space: spaceBarStyle.visibility,
            app: appBarVisibility(in: mode)
        ).contains { $0.bars[bar] == .auto && $0.shown(bar) == .always }
    }

    /// Whether `bar` is drawn at rest on `screen` in `mode`: the
    /// edge's own fold, an `auto` bar beside an `always` one included.
    public func drawsAtRest(
        _ bar: ShelfBar,
        in mode: LayoutMode,
        on screen: String?
    ) -> Bool {
        onScreen(screen).barEdges(
            space: spaceBarStyle.visibility,
            app: appBarVisibility(in: mode)
        ).contains { $0.drawnAtRest.contains(bar) }
    }

    /// The edges the bars sit on — the ONE list the reservation
    /// and the live plan both take, over settings already resolved
    /// for a screen (`onScreen(_:)`), each bar handed in with its
    /// visibility or nil where it is absent: the Space Bar's first,
    /// then the App Bar's unless the two share it, so two bars are
    /// never stacked on one edge (`ShelfSplitGeometryTests` ▸
    /// `edgesPerMode`) and `ShelfGeometry.strips` measures the
    /// Space Bar's whole edge. A shared edge reserves at the depth
    /// its most present RESERVING bar asks
    /// (`ShelfEdge.reservation`) — the folds are here, at the dedup,
    /// and nowhere beside it (`BarReserveTests`, #1524;
    /// `BarAutoHideFoldTests`, #761).
    public func barEdges(
        space: ShelfVisibility?,
        app: ShelfVisibility?
    ) -> [ShelfEdge] {
        var edges: [ShelfEdge] = []
        if let space {
            edges.append(
                ShelfEdge(
                    spaceBarStyle.edge,
                    reserves: spaceBarStyle.reserve,
                    bars: [.space: space]
                )
            )
        }
        if let app {
            if let shared = edges.firstIndex(where: {
                $0.edge == appBarStyle.edge
            }) {
                edges[shared].add(.app, app, reserves: appBarStyle.reserve)
            } else {
                edges.append(
                    ShelfEdge(
                        appBarStyle.edge,
                        reserves: appBarStyle.reserve,
                        bars: [.app: app]
                    )
                )
            }
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
            depth: kiwishelf.reservation,
            hiding: hidingEdges(in: mode, on: screen),
            hidingDepth: kiwishelf.hiddenReservation
        )
    }
}
