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
    /// `animations.on_window_resize`, echo-tracked either way —
    /// and skips the layout retile: no tiled window moved.
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
        // Accumulate against the COMMANDED frame, not the echo
        // (#129/#1056): `state.windows[id].frame` is echo-fed,
        // and mid-animation the echo lags by whole steps — so a
        // press (or a hold-to-repeat tick) landing before the
        // previous one settled re-based on stale geometry and
        // under-accumulated. The in-flight animation's target
        // IS the pending commanded value; idle, the settled
        // frame is the same truth it always was.
        let base =
            tiler.animation.targetFrame(window: id)
            ?? window.frame
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
            animated: tiler.settings.animations.onWindowResize,
            sizing: .allSpringSized
        )
        return .ok()
    }
}
