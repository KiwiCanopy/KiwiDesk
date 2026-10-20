import AppKit

/// Each App Bar item's `BarVisibility` (#2234), read from the frames
/// the layout issues and the order KiwiDesk intends — no
/// WindowServer read on the bar's refresh path. The rulings are the
/// owner's (2026-10-15, 2026-10-18) and live in the issue.
extension KiwiCore {
    /// Where a window sits and the rect it was judged on: a tile's
    /// placed frame, a float's commanded or last-reported frame.
    struct WindowPlacement: Equatable {
        var visibility: BarVisibility
        var frame: CGRect?
    }

    /// The App Bar's verdicts, through the one placement read.
    func appBarVisibility(
        of space: Space,
        floats: [WindowID]
    ) -> [WindowID: BarVisibility] {
        windowPlacements(of: space, floats: floats).mapValues(\.visibility)
    }

    /// The Spaces a screen shows, the active one included.
    func shownSpaceIDs() -> Set<SpaceID> {
        Set(
            state.workspaces.allDisplays.compactMap {
                state.workspaces.currentSpace(on: $0.id)
            } + [state.workspaces.activeSpace].compactMap { $0 }
        )
    }

    /// The verdict per window of `space`'s tiled members and
    /// `floats` — the App Bar's, and `list_windows`' for every
    /// layout (#2492; bars.md ▸ the visibility verdict's two
    /// readers). A tile named in `floats` is judged as a float,
    /// which is how a floating-mode Space's members are. Monocle
    /// shows one tile: the one its layout put in front is lit, the
    /// rest hidden. In the other non-scrolling layouts a tile
    /// another tile overlaps — a pile, an inward floor — reads
    /// covered unless it is the front one, since their order is
    /// not known. A scrolling tile is judged
    /// from the layout's frames — cut by the screen's edge, or
    /// stacked behind the tiles the scrolling raise order puts over
    /// it, the window in front on top — and no float counts against
    /// a tile. A float is lit unless the screen's edge cuts it
    /// (hidden) or the focused window, which sits above every float,
    /// covers it (hidden, or partly with no side).
    func windowPlacements(
        of space: Space,
        floats: [WindowID]
    ) -> [WindowID: WindowPlacement] {
        guard let screen = TilingEngine.screen(for: space.id, in: state)
        else { return [:] }
        let bounds = tiler.layoutBounds(on: screen, for: space)
        let laid = tiler.placedFrames(of: space, on: screen, state: state)
        let floating = Set(floats)
        let tiled = state.effectiveTiledMembers(of: space)
            .filter { !floating.contains($0) }
        let focus = appBarFocused(of: space)
        // The window the layout put in front — the focus, or
        // monocle's held member while a float holds it — or the
        // row's first, the fallback the scrolling restore takes.
        let front =
            (laid.front ?? focus).flatMap { tiled.firstIndex(of: $0) }
            ?? (tiled.isEmpty ? nil : 0)
        var placements = tileVerdicts(
            tiled,
            in: space,
            front: front,
            laid: laid
        ).mapValues { WindowPlacement(visibility: $0, frame: nil) }
        for id in tiled { placements[id]?.frame = laid.frames[id] }
        let floatFrame = { (id: WindowID) in
            self.tiler.commandedFrame(of: id) ?? self.state.windows[id]?.frame
        }
        // Only the system focus sits above the floats: a Space on
        // a screen that is not active has none (bars.md ▸ barFocus).
        let systemFocus =
            space.id == state.workspaces.activeSpace ? focus : nil
        let focusFrame = systemFocus.flatMap {
            floats.contains($0) ? floatFrame($0) : laid.frames[$0]
        }
        for id in floats {
            let frame = floatFrame(id)
            placements[id] = WindowPlacement(
                visibility: BarVisibility.judgeFloat(
                    frame,
                    on: bounds,
                    under: id == systemFocus ? nil : focusFrame
                ),
                frame: frame
            )
        }
        return placements
    }

    private func tileVerdicts(
        _ tiled: [WindowID],
        in space: Space,
        front: Int?,
        laid: (frames: [WindowID: CGRect], front: WindowID?, usable: CGRect)
    ) -> [WindowID: BarVisibility] {
        var verdicts: [WindowID: BarVisibility] = [:]
        switch space.mode {
        case .scrolling: break
        case .monocle:
            for (index, id) in tiled.enumerated() {
                verdicts[id] = index == front ? .visible : .hidden
            }
            return verdicts
        default:
            let first = front.map { tiled[$0] }
            for id in tiled {
                verdicts[id] = BarVisibility.judge(
                    laid.frames[id],
                    on: laid.usable,
                    above: id == first
                        ? []
                        : tiled.filter { $0 != id }.compactMap {
                            laid.frames[$0]
                        }
                )
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
                above: over.compactMap { laid.frames[$0] }
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
        shownSpaceIDs().contains { shownID in
            guard let space = state.workspaces[shownID],
                barHost(for: space) != nil
            else { return false }
            return appBarFloats(in: space).contains(id)
        }
    }
}
