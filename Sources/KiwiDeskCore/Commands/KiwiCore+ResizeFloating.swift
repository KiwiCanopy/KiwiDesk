import CoreGraphics
import Foundation

/// The floating half of the `resize` command, split out of
/// `KiwiCore+Resize` for file size: a floating focused window
/// resizes ITSELF — the per-layout ratio paths never see it.
extension KiwiCore {
    /// Direct resize of a floating focused window: "x" widens
    /// by the delta, "y" heightens (negative shrinks), floored
    /// at `min_window_size` — capped at the current size, so a
    /// sub-floor window never grows on a shrink.
    ///
    /// The delta is SPLIT between both edges and an edge against
    /// the boundary is pinned (#1091), so the origin moves: a
    /// chord has no grabbed edge to anchor on, and against a
    /// screen edge the old origin anchor stopped the resize dead.
    /// `FloatResize` argues it. Applies through the tiler's
    /// shared frame policy (`applyFrame`) — animated per
    /// `resizeWritesAnimated`, echo-tracked either way — and
    /// skips the layout retile: no tiled window moved.
    func resizeFloating(
        _ id: WindowID,
        axis: String,
        delta: Double
    ) -> CommandResponse {
        guard let window = state.windows[id] else {
            return .fail("unknown window")
        }
        let minSize = CGFloat(
            effectiveMinSize(of: id, axis: axis)
        )
        // Does THIS WRITE belong to a glide? The per-WRITE
        // scope, never the hold's lifetime
        // (`HoldGlide.isApplyingGlideStep` argues why a lifetime
        // bit answers it wrongly in both directions). Bound to a
        // local so this file reads it exactly once;
        // `resizeWritesAnimated` asks the same question for the
        // animation choice, in its own file.
        let isGlideWrite = keys.isApplyingGlideStep
        // Accumulate against the COMMANDED frame, not the echo
        // (#129/#1056/#1090): `state.windows[id].frame` is
        // echo-fed, and the echo lags by whole steps — so a
        // press (or a glide frame) landing before the previous
        // one was reported re-based on stale geometry and
        // under-accumulated. `commandedFrame` answers from the
        // in-flight animation's target where one exists and,
        // for a glide frame, from the record the writes below
        // keep — which is the only base there is with
        // animations off, under Reduce Motion or with the
        // engine disabled, since `animate` returns early in all
        // three. Idle, the settled frame is the same truth it
        // always was.
        //
        // Both records are BOUNDED, which is what a commanded
        // base must be here: the animation target dies at
        // settle, and the glide record is unreadable outside a
        // glide step and cleared when the run ends. The #881
        // instant stamp was tried as this base and rejected
        // precisely because it is neither — it re-arms itself
        // per press and compounds without bound on an app that
        // silently refuses every ask (#1057).
        let base =
            tiler.animation.commandedFrame(
                window: id,
                includingHeldGlide: isGlideWrite
            ) ?? window.frame
        // The region the float may occupy — screen bounds less
        // every painted bar strip (#1091). The resize needs the
        // whole rect rather than a clamp, because pinning is a
        // question about how much room each EDGE has, and a
        // clamp that only pushes can answer neither that nor
        // "this window is already wider than the space between
        // the bars".
        let region = floatGrowBounds(of: id)
        let outcome = FloatResize.resized(
            base,
            horizontal: axis == "x",
            delta: delta,
            minSize: minSize,
            bounds: region
        )
        // Growing the top edge under a top app bar would re-hide
        // the title bar; keep the result clear of the strip
        // (#242). Still applied on top of the region math: the
        // region bounds the SIZE, and this bounds the POSITION
        // for the paths that reach here with a frame the region
        // never saw.
        let target = floatFrameClampedClearOfBars(
            id,
            frame: outcome.frame
        )
        // A grow the boundary blocks or TRUNCATES cues (#1091).
        // It used to do neither: the float path cued on shrink
        // truncation only, so a blocked grow was the one resize
        // wall with no wall — and a partially blocked one
        // delivered 12 of an asked 100 in silence, which is the
        // same defect #933 already rules against at the shrink
        // end ("landing ON the minimum is already a refusal of
        // part of the request"). Cued before the shrink arm
        // below; the two are mutually exclusive by construction
        // since `Refusal` is only ever set by a grow.
        if outcome.refusal != nil {
            refuseGrowAtBoundary(id, axis: axis)
        }
        // Cue on TRUNCATION, not only on "no change": the first
        // shrink that lands ON the minimum is already a refusal
        // of part of the request (#933).
        if delta < 0 {
            let requested =
                (axis == "x"
                    ? base.width
                    : base.height) + CGFloat(delta)
            let actual =
                axis == "x" ? target.width : target.height
            if actual > requested + Self.resizeTruncationEpsilon {
                refuseShrinkAtMinimum(id, axis: axis)
            }
        }
        // Promises (#593): a float resizes ITSELF and no tiled
        // window moves — there is no sibling yielding room, and a
        // float already overlaps the layout by definition, so the
        // #45 hazard cannot arise here at all.
        tiler.applyFrame(
            id,
            from: window.frame,
            to: target,
            // The same policy every other resize write takes
            // (#1090): a glide frame writes INSTANTLY, and this
            // path now may, because the base above no longer
            // depends on an animation existing. It could not
            // before — every tiled path re-derives geometry from
            // a stored ratio, weight or length, so an instant
            // write leaves the next frame's base exact, while
            // this one measures from a FRAME and an instant
            // write creates no animation target to measure from.
            // The hold-scoped record is that missing base, so
            // the split `resizeWritesAnimated` used to argue is
            // gone: a floating glide sheds the spring's ~100–200
            // ms of trailing exactly as a tiled one does, and
            // stops generating the #611 retarget storm — a
            // changed target every frame — that the settle
            // watchdog cannot tell from a long drag.
            animated: resizeWritesAnimated,
            sizing: .allSpringSized
        )
        // Record what was just commanded, so a glide frame
        // accumulates from it rather than from an echo that has
        // not arrived. Unconditional, and the ARMING PRESS is
        // the reason: it is not a glide step, but its record is
        // exactly the base the glide's first frame needs, and a
        // press whose echo has not landed by the time the
        // key-repeat wait expires would otherwise lose its own
        // step. Nothing banks, because the read above is gated —
        // a press can never measure from another press's record.
        //
        // Deliberately NOT invalidated mid-hold on a "genuine"
        // resize the way the #677 ledger is: that classifier is
        // a heuristic, and one false genuine verdict during a
        // glide would re-base a frame on the echo and re-open
        // the defect this closes. The hold is the ceiling
        // instead — an app that refuses every ask moves nothing,
        // banks nothing past the release, and the next press
        // measures from reality.
        // The POST-clamp `target`, never `outcome.frame`. They
        // are equal whenever the region resolves and differ
        // exactly when it does not (no screen), where recording
        // the pre-clamp frame would bank a float under a bar one
        // step per glide frame — the two look interchangeable,
        // so say which (architect review, 2026-08-29).
        tiler.animation.recordGlideCommanded(id, frame: target)
        return .ok()
    }
}
