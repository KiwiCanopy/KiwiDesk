import AppKit

/// Each App Bar item's `BarVisibility` (#2234), read from the frames
/// the retile issues and the order KiwiDesk intends — no
/// WindowServer read on the bar's refresh path. The bar's own screen
/// judges it: the region its layout fills there.
extension KiwiCore {
    /// The verdict per window of `space`'s tiled members and
    /// `floats`. A float sits above every tile, the focused float
    /// above the other floats; a tile sits beneath the tiles the
    /// scrolling raise order puts over it, the window the layout
    /// put in front on top — which is monocle's stack too.
    func appBarVisibility(
        of space: Space,
        floats: [WindowID]
    ) -> [WindowID: BarVisibility] {
        guard let screen = TilingEngine.screen(for: space.id, in: state)
        else { return [:] }
        // What the layout fills: a window under a reserved strip
        // is not wholly shown, and the park's corner is in it.
        let bounds = tiler.layoutBounds(on: screen, for: space)
        let laid = tiler.placedFrames(of: space, on: screen, state: state)
        let tiled = state.effectiveTiledMembers(of: space)
        let focus = appBarFocused(of: space)
        let floatFrame = { (id: WindowID) in
            self.tiler.commandedFrame(of: id) ?? self.state.windows[id]?.frame
        }
        // The window the layout put in front — the focus, or
        // monocle's held member while a float holds it — on top;
        // the row's first where neither is a tile, the fallback
        // the scrolling restore takes.
        let front =
            (laid.front ?? focus).flatMap { tiled.firstIndex(of: $0) }
            ?? (tiled.isEmpty ? nil : 0)
        let order =
            front.map {
                Self.scrollingRaiseOrder(tiled, focusIndex: $0) + [tiled[$0]]
            } ?? []
        let floatFrames = floats.compactMap(floatFrame)
        var verdicts: [WindowID: BarVisibility] = [:]
        for id in tiled {
            let rank = order.firstIndex(of: id)
            let over = rank.map { order[($0 + 1)...] } ?? []
            verdicts[id] = judge(
                laid.frames[id],
                on: bounds,
                above: over.compactMap { laid.frames[$0] } + floatFrames
            )
        }
        for id in floats {
            let over =
                focus != id && focus.map(floats.contains) == true
                ? focus.flatMap(floatFrame).map { [$0] } ?? [] : []
            verdicts[id] = judge(floatFrame(id), on: bounds, above: over)
        }
        return verdicts
    }

    private func judge(
        _ frame: CGRect?,
        on bounds: CGRect,
        above: [CGRect]
    ) -> BarVisibility {
        BarVisibility.judge(
            frame,
            on: bounds,
            above: above,
            parked: frame.map {
                TilingEngine.looksStashed($0, in: bounds)
            } ?? false
        )
    }

    /// A float's own move or resize changes which tiles it covers
    /// with no retile behind it, so a float an App Bar lists on a
    /// shown Space re-renders the bars, debounced like a title
    /// (`handleTitleChangedForBars`).
    func handleFloatGeometryForBars(_ id: WindowID) {
        guard appBarListsShownFloat(id) else { return }
        deferred.schedule(
            .barVisibilityRefresh,
            after: Self.barTitleRefreshDelay,
            maxWait: Self.barTitleRefreshMaxWait
        ) { [weak self] in
            self?.updateBars()
        }
    }

    /// Whether `id` is a float an App Bar lists on a Space a screen
    /// shows.
    func appBarListsShownFloat(_ id: WindowID) -> Bool {
        let shown = Set(
            state.workspaces.allDisplays.compactMap {
                state.workspaces.currentSpace(on: $0.id)
            } + [state.workspaces.activeSpace].compactMap { $0 }
        )
        return shown.contains { shownID in
            guard let space = state.workspaces[shownID],
                let host = barHost(for: space), host.appBar.enabled
            else { return false }
            return appBarFloats(in: space).contains(id)
        }
    }

}
