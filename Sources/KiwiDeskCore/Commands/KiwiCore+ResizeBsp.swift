import AppKit
import Foundation

/// The BSP half of the `resize` command, split out of
/// `KiwiCore+Resize` for file size (like `+ResizeFloating` and
/// `+ResizeStack`).
extension KiwiCore {
    /// Per-axis BSP resize (#56): "x" moves a side-by-side split,
    /// "y" a stacked one — the split `BspLayout.splitOwner` names
    /// for the focused window (#3672), so +delta grows the focused
    /// window by `delta` points.
    func resizeBsp(
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) -> CommandResponse {
        // A press along a scrolled chain is a run weight (#2542).
        if let focused = space.focused,
            let response = resizeBspChain(
                focused,
                axis: axis,
                delta: delta,
                space: space,
                toward: .both
            )
        {
            return response
        }
        if let focused = space.focused {
            if let press = bspSplit(
                of: focused,
                axis: axis,
                edge: .either,
                space: space
            ), press.split.available > 0 {
                let proposed =
                    press.drawnRatio
                    + press.split.sign * delta / press.split.available
                // A press that would not move the focused window the
                // way asked refuses instead (#2969).
                if bspPressMoves(
                    focused,
                    press,
                    axis: axis,
                    delta: delta,
                    to: proposed
                ) {
                    writeCappedBspSplit(
                        press,
                        proposed: proposed,
                        axis: axis,
                        space: space,
                        focused: focused
                    )
                }
                return .ok()
            }
            if state.effectiveTiledMembers(of: space).contains(focused) {
                refuseBspNoSplit(
                    focused,
                    axis: axis,
                    grows: delta > 0,
                    space: space
                )
                return .ok()
            }
        }
        // No tiled focus: the shared ratio every split without its
        // own takes, capped at the layout region (#383).
        writeSharedBspRatio(delta: delta, axis: axis, span: span, space: space)
        return .ok()
    }
}
