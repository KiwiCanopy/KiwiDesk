import AppKit
import Foundation

/// The floating half of the `resize` command, split out of
/// `KiwiCore+Resize` for file size: a floating focused window
/// resizes ITSELF — the per-layout ratio paths never see it.
extension KiwiCore {
    /// Direct resize of a floating focused window: "x" widens
    /// by the delta, "y" heightens (negative shrinks), origin
    /// kept, floored at `min_window_size` (never below 1 pt,
    /// `FloatResize`). Applies through the tiler's frame
    /// pipeline — animated per `animations.on_window_resize`,
    /// echo-tracked either way — and skips the layout retile:
    /// no tiled window moved.
    func resizeFloating(
        _ id: WindowID,
        axis: String,
        delta: Double
    ) -> CommandResponse {
        guard let window = state.windows[id] else {
            return .fail("unknown window")
        }
        let target = FloatResize.resized(
            window.frame,
            horizontal: axis == "x",
            delta: delta,
            minSize: tiler.settings.minWindowSize
        )
        if tiler.settings.animations.onWindowResize,
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        {
            tiler.animation.animate(
                window: id,
                on: screen,
                from: window.frame,
                to: target
            )
        } else {
            tiler.setFrame(id, target)
        }
        return .ok()
    }
}
