import CoreGraphics

/// Keeps floating windows clear of every painted bar. Floats
/// are excluded from all layout geometry
/// (`TilingEngine.layoutInput` filters them out), so nothing
/// otherwise stops one from sliding under a strip. The original
/// motivator was a TOP bar covering the title bar and leaving
/// the float ungrabbable (#242); since QA 2026-07-19 all four
/// edges nudge — a bar reserves its edge for every window kind,
/// the way the Dock reserves `visibleFrame`, and a top-only
/// nudge read as an inconsistency, not a scoped decision.
///
/// Strips are read from the bars the managers actually painted
/// (`shownStrips`), never re-derived here: a second derivation
/// drifts from what is on screen — outer gaps, the empty-bar
/// suppression, per-display screen pick — and each drift is a
/// way the float ends up wrongly placed or moved for no visible
/// bar.
extension KiwiCore {
    /// `frame` nudged clear of every bar painted for the
    /// window's own space, or returned unchanged when that
    /// space shows none. Callers with a fresher read than state
    /// (a fresh drop, a resize target) pass their own frame in.
    func floatFrameClampedClearOfBars(
        _ id: WindowID,
        frame: CGRect
    ) -> CGRect {
        guard let space = state.workspaces.space(of: id)
        else { return frame }
        var result = frame
        let inset = floatRingInset
        // Order is immaterial: each clamp is a monotonic push
        // off its edge, so on a shared edge the deeper strip's
        // push subsumes the shallower one's either way.
        for (strip, edge) in spaceBarStrips(forSpace: space)
            + appBars.strips(forSpace: space)
        {
            result = AppBarGeometry.clampClear(
                result,
                of: strip,
                edge: edge,
                inset: inset
            )
        }
        return result
    }

    /// The region a float may occupy on its own space: the
    /// screen's visible bounds with every painted bar strip
    /// carved off its edge (#1091). Nil where the space resolves
    /// to no screen, which callers read as unbounded.
    ///
    /// **The ONE derivation of "where may a float sit".** The
    /// resize math takes the whole rect, because it needs to
    /// know how much room each edge has in order to pin it;
    /// `floatFrameClampedClearOfBars` above keeps pushing off
    /// bar edges only. Same fact, two scopes, and stating them
    /// apart is deliberate: that clamp runs for every float on
    /// every retile, so enforcing the screen edge there would
    /// also drag back a window the user parked half off-screen
    /// by hand, which macOS allows and this issue never asked
    /// for. Size is bounded here; POSITION stays the user's.
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
        for (strip, edge) in spaceBarStrips(forSpace: space)
            + appBars.strips(forSpace: space)
        {
            region = AppBarGeometry.regionClear(
                region,
                of: strip,
                edge: edge,
                inset: floatRingInset
            )
        }
        return region
    }

    /// How far clear of a bar a float is kept so its focus RING
    /// clears it too, not only the window (#1091): the
    /// configured ring width, or zero with rings off.
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
        return style.enabled ? style.clampedWidth : 0
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

    /// The clamp above, plus a SIZE fit into `floatBounds`
    /// (#1091). The clamp only ever moves — `clampClear` writes
    /// `origin` and never `size` — so a float larger than the
    /// space between the bars is pushed to one side and still
    /// overflows under the other, which is how a window grown
    /// before this rule (or sized by its own app) ends up
    /// unusable beneath a bar.
    ///
    /// Only the SIZE is bounded here. Position stays the user's:
    /// this runs for every float on every retile, so enforcing
    /// the screen edge as well would drag back a window parked
    /// half off-screen by hand, which macOS allows and nobody
    /// asked for.
    ///
    /// Scoped to spaces that actually SHOW a bar, because that
    /// is where the harm is — a float merely larger than the
    /// screen is the user's business, and only a bar makes part
    /// of a window unreachable. `clampFloatsClearOfBars` already
    /// iterates exactly those spaces.
    ///
    /// The fit is tolerance-gated for the reason the clamp is:
    /// re-applying a sub-point correction every retile would
    /// wobble the window.
    func floatFrameFittedClearOfBars(
        _ id: WindowID,
        frame: CGRect
    ) -> CGRect {
        var result = frame
        if let region = floatBounds(of: id) {
            let slack = AppBarGeometry.clampTolerance
            if result.width > region.width + slack {
                result.size.width = region.width
            }
            if result.height > region.height + slack {
                result.size.height = region.height
            }
        }
        return floatFrameClampedClearOfBars(id, frame: result)
    }

    /// Re-asserts the bar clamp for every floating window under
    /// a painted bar, across all displays. The structural
    /// safety net, run from `retile()` after the bars are
    /// synced: a window turned floating under an existing bar,
    /// or a bar switched on over an existing float, is
    /// corrected here. Drag and resize clamp their own fresh
    /// frame directly.
    func clampFloatsClearOfBars() {
        for space in spacesWithShownBars {
            guard let windows = state.workspaces[space]?.windows
            else { continue }
            for id in windows {
                guard let window = state.windows[id],
                    window.isFloating
                else { continue }
                // One fold over every strip, one apply: the
                // per-strip loop this replaces re-read the same
                // stale state frame for each strip (applyFrame
                // is async), so with stacked bars the second
                // clamp overwrote the first instead of
                // composing with it.
                let clamped = floatFrameFittedClearOfBars(
                    id,
                    frame: window.frame
                )
                guard clamped != window.frame else { continue }
                tiler.applyFrame(
                    id,
                    from: window.frame,
                    to: clamped,
                    animated: false
                )
            }
        }
    }

    /// Every space with at least one painted strip: the App
    /// Bars' own spaces, plus the space each Space-Bar-covered
    /// display is showing (#293: per-display bar, occludes the
    /// current space).
    private var spacesWithShownBars: Set<SpaceID> {
        var spaces = Set(appBars.shownStrips.map(\.space))
        for (display, _, _) in spaceBars.shownStrips {
            guard
                let space =
                    state.workspaces.currentSpace(on: display)
            else { continue }
            spaces.insert(space)
        }
        return spaces
    }
}
