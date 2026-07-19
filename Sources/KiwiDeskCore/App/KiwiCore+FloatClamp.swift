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
        // Space Bar first, then App Bar: on a shared edge the
        // App Bar sits window-facing (deeper), so its strip
        // decides last and wins.
        for (strip, edge) in spaceBarStrips(forSpace: space) {
            result = AppBarGeometry.clampClear(
                result,
                of: strip,
                edge: edge
            )
        }
        for (strip, edge) in appBars.strips(forSpace: space) {
            result = AppBarGeometry.clampClear(
                result,
                of: strip,
                edge: edge
            )
        }
        return result
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

    /// Re-asserts the bar clamp for every floating window under
    /// a painted bar, across all displays. The structural
    /// safety net, run from `retile()` after the bars are
    /// synced: a window turned floating under an existing bar,
    /// or a bar switched on over an existing float, is
    /// corrected here. Drag and resize clamp their own fresh
    /// frame directly.
    func clampFloatsClearOfBars() {
        var strips: [(
            space: SpaceID, strip: CGRect, edge: AppBarEdge
        )] = appBars.shownStrips
        // Space Bars occlude the same way (#293): clamp the
        // floats of the space each covered display is showing.
        strips += spaceBars.shownStrips.compactMap {
            display,
            strip,
            edge in
            state.workspaces.currentSpace(on: display)
                .map { (space: $0, strip: strip, edge: edge) }
        }
        for (space, strip, edge) in strips {
            guard let windows = state.workspaces[space]?.windows
            else { continue }
            for id in windows {
                guard let window = state.windows[id],
                    window.isFloating
                else { continue }
                let clamped = AppBarGeometry.clampClear(
                    window.frame,
                    of: strip,
                    edge: edge
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
}
