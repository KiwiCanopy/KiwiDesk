import CoreGraphics

/// Where a floating window may sit, derived once (#1091).
///
/// Split from `KiwiCore+FloatClamp` at §2.1's ceiling rather
/// than after crossing it. That file holds the two things that
/// ACT on a float — the bar clamp and the retile-time fit; this
/// one holds the region they act against, and the ring
/// reservation that separates the correctness bound from the
/// grow bound.
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
        // `BorderGeometry.outwardReach` is the named authority
        // for how far the stroke reaches PAST the window edge,
        // and `BorderStyle.fittingGaps` already routes through
        // it. `clampedWidth` equals it today and stops the day
        // reach and stroke diverge — which is exactly the
        // "ring reads as cut off" defect this inset removes
        // (architect + code review, 2026-08-29).
        return BorderGeometry.outwardReach(width: style.width)
    }

    /// **The one derivation of the region**, and the CORRECTNESS
    /// bound: a float larger than this has part of itself under
    /// a bar, which is unreachable. The retile fit measures
    /// against it.
    ///
    /// It reserves nothing for the focus ring — at a bar edge
    /// as much as at a screen edge. `floatGrowBounds` below
    /// reserves exactly one reach on every edge of it, and the
    /// two are a genuine pair of questions
    /// rather than one rect wearing two meanings (device QA,
    /// 2026-08-29): "is this window unusably large" and "how far
    /// may a deliberate grow take it" have different answers,
    /// because a clipped ring is a blemish and a window under a
    /// bar is not usable. Reserving the ring here instead would
    /// make the retile pull in a float the user had resized
    /// flush by hand — the fit fighting the hand, which the
    /// rule below forbids.
    ///
    /// Each consumer states its own scope. The resize takes
    /// `floatGrowBounds`, because pinning is a question about
    /// how much room each EDGE has; the fit takes this; and
    /// `floatFrameClampedClearOfBars` above keeps pushing off
    /// bar edges alone — that one runs for every float on every
    /// retile, so enforcing the screen edge there would drag
    /// back a window parked half off-screen by hand, which macOS
    /// allows and this issue never asked for.
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
        guard let space = state.workspaces.space(of: id),
            let screen = TilingEngine.screen(
                for: space,
                in: state
            )
        else { return nil }
        var region = tiler.visibleBounds(screen)
        for (strip, edge) in paintedStrips(forSpace: space) {
            // No ring reservation here, at a bar edge any more
            // than at a screen edge (guard-prover, 2026-08-29).
            // Carving one made this bound reserve at bars while
            // claiming to reserve nowhere, which cost two things:
            // `floatGrowBounds` then took TWO reaches at a bar,
            // and the retile fit pulled in a float the user had
            // resized flush against one — the fit fighting the
            // hand, surviving on the axis the split forgot.
            region = AppBarGeometry.regionClear(
                region,
                of: strip,
                edge: edge
            )
        }
        return region
    }

    /// Where a deliberate GROW may take a float: the region
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
    /// follows PAINTED chrome, and a ring is painted wherever it
    /// is drawn (device QA, 2026-08-29).
    ///
    /// The number is not invented here: `BorderGeometry
    /// .outwardReach` is the renderer's own, and
    /// `BorderStyle.fittingGaps` already answers the same
    /// question for the LAYOUT with the same value — an `outer`
    /// gap of exactly one reach on all four edges, single rather
    /// than doubled because only one window's ring ever meets a
    /// screen edge.
    ///
    /// Reserved regardless of whether this window is focused
    /// right now, which costs nothing where it matters: a
    /// keyboard resize acts on the FOCUSED window, so the ring
    /// is always drawn on the one being grown. An inset that
    /// tracked the ring's presence would shift a float every
    /// time it gained or lost focus.
    ///
    /// Floored rather than trusted: a ring wide enough to
    /// out-reach a small display would otherwise invert the rect
    /// and read as enormous free space.
    func floatGrowBounds(of id: WindowID) -> CGRect? {
        guard var region = floatBounds(of: id) else { return nil }
        let inset = floatRingInset
        region.size.width = max(0, region.width - inset * 2)
        region.size.height = max(0, region.height - inset * 2)
        region.origin.x += inset
        region.origin.y += inset
        return region
    }

    /// EVERY painted strip covering `space` — both bars, in one
    /// list. One accessor rather than the `spaceBarStrips +
    /// appBars.strips` expression repeated per consumer: a
    /// space shows one bar or two on any edge, and a third bar
    /// source must reach every site that asks "what chrome
    /// covers this space" (architect review, 2026-08-29).
    func paintedStrips(
        forSpace space: SpaceID
    ) -> [(strip: CGRect, edge: AppBarEdge)] {
        spaceBarStrips(forSpace: space)
            + appBars.strips(forSpace: space)
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
