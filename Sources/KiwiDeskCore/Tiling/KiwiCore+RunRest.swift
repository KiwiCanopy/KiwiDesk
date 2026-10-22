import Foundation

/// Persists where the shown Spaces' scrolled Stack zones and Track
/// tracks rest (#2235), the `ScrollRest` loop's twin: the layout
/// reads `Space.runHeads` and this writes back the heads the pass
/// drew, read off the engine's own record of it.
extension KiwiCore {
    /// The cover the active Space drew in the last retile, nil off
    /// Stack and Track.
    var activeRunCover: RunCover? {
        state.workspaces.activeSpace.flatMap { tiler.runCovers[$0] }
    }

    /// Writes the drawn heads and tails back. Hidden windows rest
    /// parked at the hide corner, overlapping nothing, so a scroll
    /// owes no z-order restore (#2235 ruling, 2026-10-22).
    func persistRunHeads() {
        for (id, cover) in tiler.runCovers {
            guard let space = state.workspaces[id],
                space.runHeads != cover.heads
                    || space.runTails != cover.tails
            else { continue }
            state.workspaces.withSpace(id) {
                $0.runHeads = cover.heads
                $0.runTails = cover.tails
            }
        }
    }

    /// Every window a shown Space's run hides (#2235).
    var runHidden: Set<WindowID> {
        Set(tiler.runCovers.values.flatMap { $0.behind.keys })
    }

    /// The slots a classifier reads — a geometric step, a drop
    /// target, a pile test: `calculatedFrames` without the windows
    /// a run hides, which all park at one corner and so would read
    /// as a pile there. The one door, so a new
    /// classifier cannot forget the filter. The slots are fresh,
    /// the hidden set the last pass's: between a membership change
    /// and its retile, a window can read on the wrong side of the
    /// run for one press.
    func shownSlots() -> [WindowID: CGRect] {
        let hidden = runHidden
        return tiler.calculatedFrames(state: state).filter {
            !hidden.contains($0.key)
        }
    }

    /// Whether a focus on `id` scrolls a run: the window waits
    /// hidden in the active Space, so the run must move to show
    /// it — the one focus a Stack or Track pass answers, since
    /// focus drives the scroll (#2235 ruling).
    func focusScrollsRun(to id: WindowID) -> Bool {
        activeRunCover?.behind[id] != nil
    }

    /// Whether a focus on `id` owes a pass: a focus-driven layout
    /// always, Stack or Track where the focus scrolls a run. The
    /// one predicate the commanded focus and the focus report share.
    func focusRetiles(to id: WindowID) -> Bool {
        activeSpace?.mode.isFocusDriven == true || focusScrollsRun(to: id)
    }

    /// The Track frames `input` draws, less what its runs park —
    /// what a track restore and its gate judge for a pile.
    func shownTrackFrames(
        _ input: (space: Space, tiled: [WindowID], context: LayoutContext)
    ) -> [WindowID: CGRect] {
        dropRunHidden(
            TrackLayout().calculateGeometry(
                for: input.tiled,
                in: input.context
            ),
            space: input.space.id,
            mode: .track,
            tiled: input.tiled,
            in: input.context
        )
    }

    /// `frames` without the windows the run `mode` draws over
    /// `tiled` hides: parked at one corner, they would read as a
    /// pile to a z-order restore and its gate (#2235).
    func dropRunHidden(
        _ frames: [WindowID: CGRect],
        space: SpaceID,
        mode: LayoutMode,
        tiled: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        guard
            let hidden = RunCover.of(
                space: space,
                mode: mode,
                tiled: tiled,
                in: context
            )?.behind
        else { return frames }
        return frames.filter { hidden[$0.key] == nil }
    }
}
