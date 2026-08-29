import CoreGraphics
import Foundation

/// The floating half of the `resize` command, split out of
/// `KiwiCore+Resize` for file size: a floating focused window
/// resizes ITSELF — the per-layout ratio paths never see it.
extension KiwiCore {
    /// Direct resize of a floating focused window: "x" widens
    /// by the delta, "y" heightens (negative shrinks), origin
    /// kept, floored at `min_window_size` — capped at the
    /// current size, so a sub-floor window never grows on a
    /// shrink (`FloatResize`). Applies through the tiler's
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
        // Does THIS WRITE belong to a glide? Bound once and
        // read twice below — the per-WRITE scope, never the
        // hold's lifetime (`HoldGlide.isApplyingGlideStep`
        // argues why a lifetime bit answers it wrongly in both
        // directions). `resizeWritesAnimated` asks the same
        // question for the animation choice.
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
        // Growing the top edge under a top app bar would re-hide
        // the title bar; keep the result clear of the strip (#242).
        let target = floatFrameClampedClearOfBars(
            id,
            frame: FloatResize.resized(
                base,
                horizontal: axis == "x",
                delta: delta,
                minSize: minSize
            )
        )
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
        tiler.animation.recordGlideCommanded(id, frame: target)
        return .ok()
    }
}
