import AppKit

/// Each App Bar item's `BarVisibility` (#2234), read from the frames
/// the layout issues and the order KiwiDesk intends — no
/// WindowServer read on the bar's refresh path. The rulings are the
/// owner's (2026-10-15, 2026-10-18) and live in the issue.
extension KiwiCore {
    /// The verdict per window of `space`'s tiled members and
    /// `floats`. Monocle shows one tile: the one its layout put in
    /// front is lit, the rest hidden. A scrolling tile is judged
    /// from the layout's frames — cut by the screen's edge, or
    /// stacked behind the tiles the scrolling raise order puts over
    /// it, the window in front on top — and no float counts against
    /// a tile. A float is lit unless the screen's edge cuts it
    /// (hidden) or the focused window, which sits above every float,
    /// covers it (hidden, or partly with no side).
    func appBarVisibility(
        of space: Space,
        floats: [WindowID]
    ) -> [WindowID: BarVisibility] {
        guard let screen = TilingEngine.screen(for: space.id, in: state)
        else { return [:] }
        let bounds = tiler.layoutBounds(on: screen, for: space)
        let laid = tiler.placedFrames(of: space, on: screen, state: state)
        let tiled = state.effectiveTiledMembers(of: space)
        let focus = appBarFocused(of: space)
        // The window the layout put in front — the focus, or
        // monocle's held member while a float holds it — or the
        // row's first, the fallback the scrolling restore takes.
        let front =
            (laid.front ?? focus).flatMap { tiled.firstIndex(of: $0) }
            ?? (tiled.isEmpty ? nil : 0)
        var verdicts = tileVerdicts(
            tiled,
            in: space,
            front: front,
            laid: laid
        )
        let floatFrame = { (id: WindowID) in
            self.tiler.commandedFrame(of: id) ?? self.state.windows[id]?.frame
        }
        let focusFrame = focus.flatMap {
            floats.contains($0) ? floatFrame($0) : laid.frames[$0]
        }
        for id in floats {
            let seen = BarVisibility.judge(
                floatFrame(id),
                on: bounds,
                above: id == focus ? [] : focusFrame.map { [$0] } ?? [],
                parked: false
            )
            // A float takes no half-moon: its edges are where the
            // user put it, not a way to scroll.
            if case .partly(let side) = seen, side != nil {
                verdicts[id] = .hidden
            } else {
                verdicts[id] = seen
            }
        }
        return verdicts
    }

    private func tileVerdicts(
        _ tiled: [WindowID],
        in space: Space,
        front: Int?,
        laid: (frames: [WindowID: CGRect], front: WindowID?, usable: CGRect)
    ) -> [WindowID: BarVisibility] {
        var verdicts: [WindowID: BarVisibility] = [:]
        guard space.mode == .scrolling else {
            for (index, id) in tiled.enumerated() {
                verdicts[id] = index == front ? .visible : .hidden
            }
            return verdicts
        }
        let order =
            front.map {
                Self.scrollingRaiseOrder(tiled, focusIndex: $0) + [tiled[$0]]
            } ?? []
        // Judged against the area the layout fills, so the row's
        // edge sliver measures as the sliver.
        for id in tiled {
            let rank = order.firstIndex(of: id)
            let over = rank.map { order[($0 + 1)...] } ?? []
            verdicts[id] = BarVisibility.judge(
                laid.frames[id],
                on: laid.usable,
                above: over.compactMap { laid.frames[$0] },
                parked: false
            )
        }
        return verdicts
    }

    /// A float's own move or resize changes how the focused window
    /// covers it with no retile behind it, so a float an App Bar
    /// lists on a shown Space re-renders the bars, debounced like a
    /// title (`handleTitleChangedForBars`).
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
