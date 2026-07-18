import CoreGraphics

/// Keeps floating windows clear of a TOP app bar. Floats are
/// excluded from all layout geometry (`TilingEngine.layoutInput`
/// filters them out), so nothing otherwise stops one from sitting
/// under a top bar strip — which covers its title bar and leaves
/// it ungrabbable (#242). Only a TOP bar occludes the title bar;
/// bottom/left/right bars need no correction.
///
/// The strip is read from the bars `AppBarManager` actually
/// painted (`shownTopStrips`), never re-derived here: a second
/// derivation drifts from what is on screen — outer gaps, the
/// empty-bar suppression, per-display screen pick — and each drift
/// is a way the float ends up wrongly placed or moved for no
/// visible bar.
extension KiwiCore {
    /// `frame` pushed below the top app bar of the window's own
    /// space, or returned unchanged when that space shows none.
    /// Callers with a fresher read than state (a fresh drop, a
    /// resize target) pass their own frame in.
    func floatFrameClampedBelowTopBar(
        _ id: WindowID,
        frame: CGRect
    ) -> CGRect {
        guard let space = state.workspaces.space(of: id)
        else { return frame }
        var result = frame
        // Combined top reservation (#293): a top Space Bar and a
        // top App Bar stack, so clamp below each painted strip
        // in turn — the deeper one wins.
        if let strip = spaceBarTopStrip(forSpace: space) {
            result = AppBarGeometry.clampBelowTopStrip(
                result,
                strip: strip
            )
        }
        if let strip = appBars.topStrip(forSpace: space) {
            result = AppBarGeometry.clampBelowTopStrip(
                result,
                strip: strip
            )
        }
        return result
    }

    /// The painted top Space Bar strip covering `space`, or nil.
    /// The Space Bar is per-display; a space is covered by the
    /// bar of the display currently showing it.
    private func spaceBarTopStrip(
        forSpace space: SpaceID
    ) -> CGRect? {
        spaceBars.shownTopStrips.first { display, _ in
            state.workspaces.currentSpace(on: display) == space
        }?.strip
    }

    /// Re-asserts the top-bar clamp for every floating window under
    /// a painted top bar, across all displays. The structural
    /// safety net, run from `retile()` after the bars are synced: a
    /// window turned floating under an existing bar, or a bar
    /// switched on over an existing float, is corrected here. Drag
    /// and resize clamp their own fresh frame directly.
    func clampFloatsBelowTopBars() {
        var strips = appBars.shownTopStrips
        // Top Space Bars occlude the same way (#293): clamp the
        // floats of the space each covered display is showing.
        strips += spaceBars.shownTopStrips.compactMap {
            display,
            strip in
            state.workspaces.currentSpace(on: display)
                .map { (space: $0, strip: strip) }
        }
        for (space, strip) in strips {
            guard let windows = state.workspaces[space]?.windows
            else { continue }
            for id in windows {
                guard let window = state.windows[id],
                    window.isFloating
                else { continue }
                let clamped = AppBarGeometry.clampBelowTopStrip(
                    window.frame,
                    strip: strip
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
