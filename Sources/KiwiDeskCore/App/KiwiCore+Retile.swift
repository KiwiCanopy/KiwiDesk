import CoreGraphics

/// The one place a layout pass is driven from (`KiwiCore.retile`).
/// Everything a reflow must keep in step — the persisted scroll
/// offset, both bars, both overlay families, the float clamp —
/// runs here in a fixed order, so a new caller cannot forget half
/// of it. Split out of `KiwiCore.swift` to keep that file under
/// the size ceiling.
extension KiwiCore {
    /// `animated: nil` (the default for a bare `retile()`) means
    /// "a structural reflow" — window open/close, mode / gap /
    /// param change — and obeys `animations.on_relayout`. Callers
    /// that own a more specific trigger (space switch, swap,
    /// resize, focus slide) pass an explicit `animated:` and are
    /// gated by their own toggle instead.
    ///
    /// `sizing: .allSpringSized` promises that every window this
    /// pass touches is spring-sized (#593), which lets a shrinking
    /// pane slide its shared edge instead of snapping. Opt-in and
    /// allow-listed — `BatchSizingRoutingTests` names every call
    /// site that may promise, and `BatchSizing` argues why
    /// guessing is the one mistake that reintroduces #45.
    public func retile(
        animated: Bool? = nil,
        force: Bool = false,
        newlyCreatedWindow: WindowID? = nil,
        stashAnimated: Bool = false,
        sizing: BatchSizing = .mayInstantSize
    ) {
        // Session weights are validated at WRITE time against
        // the membership at press time; a membership or span
        // change afterwards can leave them infeasible, and the
        // layouts answer that by piling the whole group (#944).
        // Heal them here, before the pass renders — every such
        // change already retiles, so this is the one choke
        // point and needs no per-site arming.
        healTrackSessionWeights()
        tiler.retile(
            state: state,
            animated: animated
                ?? tiler.settings.animations.onRelayout,
            force: force,
            newlyCreatedWindow: newlyCreatedWindow,
            stashAnimated: stashAnimated,
            sizing: sizing
        )
        // A retile-channel observation confirmed a bound
        // mid-pass (#677): the pass computed its frames BEFORE
        // believing it, so run the placement now rather than
        // leaving the residue for the next unrelated event.
        // Terminates: the second pass re-observes the same
        // answer, which is no confirmation edge.
        if tiler.takePendingBoundPlacement() {
            onLog(
                "size bound confirmed during retile; "
                    + "placing residue"
            )
            tiler.retile(
                state: state,
                animated: animated
                    ?? tiler.settings.animations.onRelayout,
                force: false,
                stashAnimated: stashAnimated,
                sizing: sizing
            )
        }
        // Scrolling reads back its own last rest (#66); other
        // modes never write `scrollRest`, so this is a no-op
        // for them.
        persistScrollRest()
        updateAppBar()
        updateSpaceBar()
        // Rings ride the same freshness as the bar: every
        // structural / focus / mode / settings retile. Runs after
        // the layout above so it reads the just-updated state
        // frames (steady state); per-tick moves come from the
        // animation tee (`tiler.onFrameApplied`).
        updateBorders()
        // The sticky marks ride the same freshness (#414).
        updateStickyMarks()
        // An animated relayout (spawn, close, mode/gap change)
        // restacks windows, so WindowServer fires the same
        // hide/reorder events as a drag-swap — which can leave a
        // ring hidden with no matching unhide. Re-assert the full
        // ring set while the motion is under way (keyed, so a
        // burst of retiles collapses to one). Only when something
        // animates: a static retile moves nothing, so no restack,
        // no drop. The geometry half of the heal is separate and
        // lands after the motion stops (`scheduleBorderResync`,
        // #596) — this pass is visibility only, and cannot move an
        // animating window's ring.
        if tiler.animation.activeCount > 0 {
            scheduleBorderDropReconcile()
        }
        // Floats sit outside the layout loop above, so a bar just
        // switched on (or a window just turned floating) can leave
        // one hidden under a top strip; correct it here. Must run
        // after `updateAppBar()`: the clamp reads the strips it
        // just painted (#242).
        clampFloatsClearOfBars()
    }
}
