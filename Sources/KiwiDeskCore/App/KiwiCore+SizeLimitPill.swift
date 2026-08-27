import AppKit
import CoreGraphics

extension KiwiCore {
    /// Flashes the minimum-size refusal pill on `window`
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
    /// and the minimum-size refusal pill when a shrink attempt
    /// hits the window's effective minimum size limit (#933).
    /// Fires on the first attempt the clamp truncates — landing
    /// ON the minimum included — not only once already there.
    func refuseShrinkAtMinimum(_ window: WindowID, axis: String) {
        keys.noteResizeRefusal()
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

    /// Cues a grow refused at the window's own learned
    /// app-enforced maximum (#1055) — `refuseShrinkAtMinimum`'s
    /// mirror at the other end. One pill only: the limit is the
    /// resized window's own app, so there is no second window
    /// to mark, and the bump stays on the gesture that hit the
    /// wall.
    func refuseGrowAtMaximum(_ window: WindowID, axis: String) {
        borders.onResizeRefusal(.ownMaximum(window))
        let direction: Direction = axis == "y" ? .down : .right
        flashDeadEnd(window, direction: direction)
        flashSizeLimitPill(
            window,
            text: L(
                "resize.max_size_reached",
                "Maximum window size reached"
            )
        )
    }

    /// Cues a resize refused because a NEIGHBOR sits at its own
    /// effective minimum (#933): the bump stays on the resized
    /// window (the gesture hit a wall), and BOTH ends pill with
    /// the text that fits its anchor — the resized window
    /// explains why nothing moved ("Neighboring window at its
    /// minimum size"), the blocking window marks itself
    /// ("Minimum window size reached"). One pill on the blocker
    /// alone read absurd there — from its own perspective IT
    /// reached the minimum, not a neighbor — and one on the
    /// trier alone leaves which window blocks unnamed (owner
    /// ruling, 2026-08-22; the #435 anchor rule still holds:
    /// the window that cannot move is marked).
    func refuseGrowAtNeighborMinimum(
        _ focused: WindowID,
        anchor: WindowID,
        axis: String
    ) {
        keys.noteResizeRefusal()
        borders.onResizeRefusal(
            .neighborMinimum(anchor: anchor, focused: focused)
        )
        let direction: Direction = axis == "y" ? .down : .right
        flashDeadEnd(focused, direction: direction)
        flashSizeLimitPill(
            focused,
            text: L(
                "resize.neighbor_min_size",
                "Neighboring window at its minimum size"
            )
        )
        flashSizeLimitPill(
            anchor,
            text: L(
                "resize.min_size_reached",
                "Minimum window size reached"
            )
        )
    }
}
