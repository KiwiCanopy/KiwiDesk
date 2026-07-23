import AppKit
import CoreGraphics

/// Cross-display re-anchor for floating windows (#444).
///
/// Delivery deliberately rides the stash-capture machinery: the
/// translated frame is seeded as the float's stash "original",
/// and `restoreStashed` — which already handles echo lag, the
/// drag exemption, and removed displays — applies it on the
/// retile every move already runs. That is instant when the
/// target space is visible on its monitor, and deferred to the
/// activation that un-parks the float when it is not. No second
/// apply path to drift.
extension KiwiCore {
    /// Re-anchors floating `id` onto `target`'s display when
    /// that differs from the display its frame sits on. No-op
    /// for tiled windows (the layout owns their frames),
    /// same-display moves (#412 stash behavior unchanged), and
    /// global stickies (visible everywhere, so a membership move
    /// never needs to teleport one; a DISPLAY sticky re-homes
    /// across monitors — `stickyMoveRefused` allows it — and
    /// re-anchors like any float). Callers run this AFTER the
    /// membership move so the target space resolves the bars.
    func reanchorFloat(_ id: WindowID, to target: SpaceID) {
        guard let window = state.windows[id],
            window.isFloating,
            window.stickyScope != .global
        else { return }
        // A parked float's state frame is the stash corner; the
        // pending capture is the real frame to translate.
        let base = tiler.stashOriginal(id) ?? window.frame
        guard
            let targetScreen = TilingEngine.screen(
                for: target,
                in: state
            ),
            let sourceScreen = TilingEngine.screen(
                containing: base
            ) ?? NSScreen.main ?? NSScreen.screens.first
        else { return }
        let source = GeometryUtils.axVisibleFrame(
            of: sourceScreen
        )
        let dest = GeometryUtils.axVisibleFrame(of: targetScreen)
        guard source != dest else { return }
        let translated = FloatReanchor.target(
            frame: base,
            from: source,
            to: dest
        )
        // Clear of the target display's painted bars — the same
        // clamp every float gets (#242). The membership already
        // moved, so the strips resolve for the TARGET space.
        tiler.seedStash(
            id,
            frame: floatFrameClampedClearOfBars(
                id,
                frame: translated
            )
        )
    }
}
