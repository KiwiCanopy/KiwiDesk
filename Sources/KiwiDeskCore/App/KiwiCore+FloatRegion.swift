import CoreGraphics

/// Where a floating window may sit, derived once (#1091).
///
/// Split from `KiwiCore+FloatClamp`, which holds the top-bar push
/// that ACTS on a float; this one holds the bounds a float is placed
/// or stepped within — the region, the grow bound and the verbs'
/// reach (#3163) — over one derivation, and the ring reservation.
///
/// Reads the display through `TilingEngine.visibleBounds`
/// (#531), never `GeometryUtils.axVisibleFrame` — a direct call
/// reds `VisibleBoundsRoutingTests`, and this file's entry in
/// `LayoutBoundsRoutingTests`' `allowed` map is why the raw
/// read is permitted here at all.
extension KiwiCore {
    /// How far clear of the region's edges a float is kept so
    /// its focus RING clears them too, not only the window
    /// (#1091) — bars and screen edges alike, since a ring is
    /// painted wherever it is drawn. Zero with rings off, which
    /// is the escape: nothing is reserved for chrome that is not
    /// on screen.
    ///
    /// Read from the configured style rather than a window's own
    /// spec, and applied to every float regardless of focus. An
    /// inset that tracked the ring's actual presence would shift
    /// a float a few points each time it gained or lost focus —
    /// which is worse than the sliver it would recover.
    // Internal rather than private so the guard can read it:
    // the strips it feeds are only reachable through a painted
    // bar, so a test that went the long way round would be
    // guarding `AppBarManager.sync` instead of this rule.
    var floatRingInset: CGFloat {
        let style = tiler.settings.borderStyle
        guard style.enabled else { return 0 }
        // The ring's reach past the edge, glow included and
        // rounded up as `fittingGaps` rounds it (#1378).
        return BorderGeometry.outwardReach(
            width: style.width,
            glowBlur: style.glowBlur(focused: true)
        ).rounded(.up)
    }

    /// **The region**, every reserved strip carved off: the bound
    /// `center_floating` and the gather act within. No sweep fits a
    /// float into it (#3163), and the stepping verbs reach
    /// `floatReachBounds` instead.
    ///
    /// It reserves nothing for the focus ring — at a bar edge
    /// as much as at a screen edge. `floatGrowBounds` below
    /// reserves exactly one reach on every edge of it, and the
    /// two are a genuine pair of questions
    /// rather than one rect wearing two meanings (device QA,
    /// 2026-08-29): "is this window in the region" and "where may a
    /// placement lay it" have different answers, because a clipped
    /// ring is a blemish.
    ///
    /// Each consumer states its own scope. A placement nothing
    /// corrects takes `floatGrowBounds`. The resize takes
    /// `floatReachBounds(ringInset:)`, a rect rather than a clamp
    /// because pinning asks how much room each EDGE has.
    /// `floatFrameClampedClearOfBars` pushes off a top bar alone
    /// (#3163): it runs for every float on every retile, so any
    /// other edge would move a window the user placed.
    ///
    /// Bars vary per space — one bar or two, on any edge — so
    /// this folds both strip lists exactly as the clamp does
    /// rather than assuming a count or an edge. Two strips on
    /// ONE edge leave the deeper carve standing, which is the
    /// monotonicity `AppBarGeometry.regionClear` provides and
    /// the reason the fold needs no ordering rule.
    ///
    /// Reads the display through `TilingEngine.visibleBounds`
    /// (#531), never `GeometryUtils.axVisibleFrame` — a direct
    /// call reds `VisibleBoundsRoutingTests`.
    func floatBounds(of id: WindowID) -> CGRect? {
        guard let space = state.workspaces.space(of: id)
        else { return nil }
        return floatBounds(on: space)
    }

    /// The region a float may occupy on `space` — the arm a
    /// traveler takes for the space it RENDERS on (#1217).
    func floatBounds(on space: SpaceID) -> CGRect? {
        floatArea(on: space, carving: reservedStrips(forSpace: space))
    }

    /// The one derivation beneath every float bound: `space`'s
    /// screen, its visible bounds, `strips` carved off their edges.
    /// No ring reservation here, at a bar edge any more than at a
    /// screen edge: `ringReserved` adds one reach, and a carve here
    /// made a bound take two at a bar.
    private func floatArea(
        on space: SpaceID,
        carving strips: [(strip: CGRect, edge: AppBarEdge)]
    ) -> CGRect? {
        guard
            let screen = TilingEngine.screen(for: space, in: state)
        else { return nil }
        var area = tiler.visibleBounds(screen)
        for (strip, edge) in strips {
            area = AppBarGeometry.regionClear(area, of: strip, edge: edge)
        }
        return area
    }

    /// `rect` with the focus ring's reach reserved once on every
    /// edge. Floored rather than trusted: a ring wide enough to
    /// out-reach a small display would otherwise invert the rect and
    /// read as enormous free space.
    private func ringReserved(_ rect: CGRect) -> CGRect {
        let inset = floatRingInset
        return CGRect(
            x: rect.minX + inset,
            y: rect.minY + inset,
            width: max(0, rect.width - inset * 2),
            height: max(0, rect.height - inset * 2)
        )
    }

    /// Where a placement may lay a float: the region
    /// above with the focus ring's own outward reach reserved
    /// ONCE on every edge — bars and screen edges alike, and
    /// once rather than twice, which is why the bound above
    /// carves its strips without an inset.
    ///
    /// A ring is the window frame outset by that reach and
    /// paints at `.normal` while bars paint at `BarPanel.level`,
    /// so a window flush against a strip has its outer sliver
    /// hidden and one flush against a screen edge has it
    /// clipped. Reserving at bars but not at screen edges was
    /// two rules where the principle gives one — float geometry
    /// follows RESERVED chrome (#1524: a bar drawn over the
    /// windows keeps no float out), and a ring reserves wherever
    /// it is drawn (device QA, 2026-08-29).
    ///
    /// The number is not invented here: `BorderGeometry
    /// .outwardReach` is the renderer's own, and
    /// `BorderStyle.fittingGaps` already answers the same
    /// question for the LAYOUT with the same value — an `outer`
    /// gap of exactly one reach on all four edges, single rather
    /// than doubled because only one window's ring ever meets a
    /// screen edge.
    ///
    /// Reserved regardless of whether the window is focused, so an
    /// inset that tracked the ring's presence never shifts a float
    /// each time it gains or loses focus.
    func floatGrowBounds(of id: WindowID) -> CGRect? {
        guard let space = state.workspaces.space(of: id)
        else { return nil }
        return floatGrowBounds(on: space)
    }

    /// The grow bound on `space` — where a PLACEMENT nothing else
    /// will correct lays a frame (the #1177 gather), so the clamp
    /// has no ring push left to make.
    func floatGrowBounds(on space: SpaceID) -> CGRect? {
        floatBounds(on: space).map(ringReserved)
    }

    /// Where a float VERB that steps or grows may take a window
    /// (#3163, owner ruling 2026-11-10): the screen's visible bounds
    /// less `floatStoppingStrips`, the place a hand drag reaches, so
    /// a bottom or side bar stops neither route. A step reaches the
    /// bare edge; `ringInset` holds the ring clear for a grow, which
    /// acts on the FOCUSED window, so the ring is always drawn on the
    /// one being grown.
    func floatReachBounds(
        on space: SpaceID,
        ringInset: Bool = false
    ) -> CGRect? {
        let reach = floatArea(
            on: space,
            carving: floatStoppingStrips(forSpace: space)
        )
        return ringInset ? reach.map(ringReserved) : reach
    }

    /// The strips that stop or push a placed float: reserved ones on
    /// the TOP edge alone (#3163). The push and the verbs' reach read
    /// this one answer, so a key and the mouse stop at the same place
    /// and the push never fights a keyboard move.
    func floatStoppingStrips(
        forSpace space: SpaceID
    ) -> [(strip: CGRect, edge: AppBarEdge)] {
        reservedStrips(forSpace: space).filter { $0.edge == .top }
    }

    /// EVERY painted strip covering `space` on an edge the
    /// layout RESERVES — both bars, in one list. The edge is
    /// judged by the one fold `shelfEdges(in:on:)`, never per
    /// section: on a fused edge either bar's reserve holds the
    /// whole strip — the non-reserving bar's painted section
    /// included, where the reserving one paints nothing — so a
    /// float is kept out where a tiled window is (#1524,
    /// `BarReserveCoreTests` ▸ `fusedEdgeFoldCarvesUnpaintedReserver`).
    /// One accessor so a third bar source reaches every site that
    /// asks "what chrome covers this space" (architect review,
    /// 2026-08-29).
    func reservedStrips(
        forSpace space: SpaceID
    ) -> [(strip: CGRect, edge: AppBarEdge)] {
        let mode = state.workspaces[space]?.mode ?? .bsp
        let display = state.workspaces.display(of: space)
        let screen = display.flatMap(screenFingerprint(of:))
        // Through the shelf's door: a tiling-off Space's Hidden bars
        // and Pocket reserve nothing (#3151).
        let shown = display.map(shelfSettings(on:)) ?? tiler.settings
        let reserved = shown.shelfEdges(in: mode, on: screen)
        let bars = paintedStrips(forSpace: space).filter {
            reserved.contains($0.edge)
        }
        // The whole pocket reserves a shelf's strip, so a float keeps
        // clear of it as of a bar (#2784).
        guard shown.pocketRests,
            shown.pocketRest(in: mode, on: screen) == .mark,
            shown.pocketReservation(in: mode, on: screen) != nil,
            let display, let mark = pocketMarkFrame(on: display)
        else { return bars }
        return bars + [(mark, tiler.settings.kiwishelf.pocketEdge)]
    }

    /// Every bar strip painted over `space`, reserved or drawn over
    /// the windows.
    func paintedStrips(
        forSpace space: SpaceID
    ) -> [(strip: CGRect, edge: AppBarEdge)] {
        spaceBarStrips(forSpace: space) + appBars.strips(forSpace: space)
    }

    /// The painted Space Bar strips covering `space`. The
    /// Space Bar is per-display; a space is covered by the
    /// bar of the display currently showing it.
    private func spaceBarStrips(
        forSpace space: SpaceID
    ) -> [(strip: CGRect, edge: AppBarEdge)] {
        spaceBars.shownStrips
            .filter { display, _, _ in
                state.workspaces.currentSpace(on: display)
                    == space
            }
            .map { (strip: $0.strip, edge: $0.edge) }
    }
}
