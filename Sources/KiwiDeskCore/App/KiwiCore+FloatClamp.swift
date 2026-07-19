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
        // Order is immaterial: each clamp is a monotonic push
        // off its edge, so on a shared edge the deeper strip's
        // push subsumes the shallower one's either way.
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
                let clamped = floatFrameClampedClearOfBars(
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
