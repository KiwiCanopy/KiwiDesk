import AppKit
import CoreGraphics

extension KiwiCore {
    /// Flashes the minimum size indicator pill on `window`
    /// (#933) with `text`.
    private func flashSizeLimitPill(
        _ window: WindowID,
        text: String
    ) {
        guard
            let frame = tiler.calculatedFrames(state: state)[window]
                ?? state.windows[window]?.frame
        else { return }
        borders.flashSizeLimitPill(
            window: window,
            frame: frame,
            text: text
        )
    }

    /// Triggers both the DeadEndBump rubber-band on the focus ring
    /// and the minimum size indicator pill when a shrink attempt
    /// hits the window's effective minimum size limit (#933).
    /// Fires on the first attempt the clamp truncates — landing
    /// ON the minimum included — not only once already there.
    func refuseShrinkAtMinimum(_ window: WindowID, axis: String) {
        borders.onResizeRefusal(.ownMinimum(window))
        let direction: Direction = axis == "y" ? .down : .right
        flashDeadEnd(window, direction: direction)
        flashSizeLimitPill(
            window,
            text: L(
                "resize.min_size_reached",
                "Minimum window size reached"
            )
        )
    }

    /// Cues a grow refused because a NEIGHBOR sits at its own
    /// effective minimum (#933): the bump stays on the resized
    /// window (the gesture hit a wall), while the pill goes on
    /// `anchor` — the window that cannot shrink, not the trier,
    /// the #435 sticky-swap rule.
    func refuseGrowAtNeighborMinimum(
        _ focused: WindowID,
        anchor: WindowID,
        axis: String
    ) {
        borders.onResizeRefusal(
            .neighborMinimum(anchor: anchor, focused: focused)
        )
        let direction: Direction = axis == "y" ? .down : .right
        flashDeadEnd(focused, direction: direction)
        flashSizeLimitPill(
            anchor,
            text: L(
                "resize.neighbor_min_size",
                "Neighboring window at its minimum size"
            )
        )
    }
}
