import AppKit
import Foundation

/// The BSP half of the `resize` command, split out of
/// `KiwiCore+Resize` for file size (like `+ResizeFloating` and
/// `+ResizeStack`): the per-axis ratio write and the
/// focused-window sign rule.
extension KiwiCore {
    /// Per-axis BSP resize (#56): "x" moves the side-by-side
    /// splits, "y" the stacked splits — independent knobs. The
    /// delta's sign follows the FOCUSED window (#122): a slot
    /// in the second (right/bottom) region grows when the
    /// shared ratio DROPS, so +delta always grows the focused
    /// region — mouse-path parity (`MouseResize.translate`).
    func resizeBsp(
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) -> CommandResponse {
        let bsp = tiler.settings.resolvedBsp(for: space)
        let signed =
            bspFocusSign(axis: axis, space: space)
            * delta
        // Cap the write at the display's effective range (#383):
        // past it the layout clamps anyway and the stored value
        // would only ratchet invisibly, exactly like the stack
        // path (#44). Span is the raw screen extent (a superset of
        // the gap-adjusted range) so the cap never blocks reaching
        // the visible bound.
        let minSize = Double(tiler.settings.minWindowSize)
        if axis == "x" {
            let value = SplitDomain.cappedRatioWrite(
                bsp.splitRatioH + signed / span,
                base: bsp.splitRatioH,
                available: span,
                minSize: minSize
            )
            writeSplitRatioH(
                min(max(value, 0.1), 0.9),
                for: space.id
            )
        } else {
            let value = SplitDomain.cappedRatioWrite(
                bsp.splitRatioV + signed / span,
                base: bsp.splitRatioV,
                available: span,
                minSize: minSize
            )
            writeSplitRatioV(
                min(max(value, 0.1), 0.9),
                for: space.id
            )
        }
        return .ok()
    }

    /// Which way the shared BSP ratio must move so "grow"
    /// grows the FOCUSED window — the mouse path's side rule,
    /// via the shared authority (`MouseResize.bspSide`).
    /// Unknown focus (none, or floating — no slot) keeps +1,
    /// the first-region direction (the pre-#122 behavior).
    /// Assumes `space` IS the active space: the slot lookup
    /// resolves the active space's frames only, so any other
    /// space silently gets the +1 fallback.
    private func bspFocusSign(
        axis: String,
        space: Space
    ) -> Double {
        guard let focused = space.focused,
            let slot = tiler.calculatedFrames(
                state: state
            )[focused],
            let screen = TilingEngine.screen(
                for: space.id,
                in: state
            )
        else { return 1 }
        return Double(
            MouseResize.bspSide(
                slot: slot,
                bounds: tiler.displayBounds(screen),
                horizontal: axis == "x"
            )
        )
    }
}
