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
        // Growing the top edge under a top app bar would re-hide
        // the title bar; keep the result clear of the strip (#242).
        let target = floatFrameClampedBelowTopBar(
            id,
            frame: FloatResize.resized(
                window.frame,
                horizontal: axis == "x",
                delta: delta,
                minSize: tiler.settings.minWindowSize
            )
        )
        tiler.applyFrame(
            id,
            from: window.frame,
            to: target,
            animated: tiler.settings.animations.onWindowResize
        )
        return .ok()
    }
}
