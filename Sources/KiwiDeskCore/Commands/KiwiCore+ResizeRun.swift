import Foundation

/// A weight resize inside a scrolled run (#2235): the layout gives
/// every shown window its floor and divides only what is left by
/// weight (`ZoneRun.frames`), so the press divides that span over
/// the shown windows alone — the span the layout divides (#933),
/// and never a hidden window named in a refusal (#1259).
extension KiwiCore {
    /// The write for `focused` when its zone is laid by floor and
    /// weight — a run, hiding windows or not (#2774) — nil
    /// otherwise, and the caller then takes the whole-zone clamp.
    /// The stack and the track member writers share it, each
    /// stating whether its other axis divides (#1258).
    func resizeInRun(
        _ focused: WindowID,
        axis: String,
        delta: Double,
        space: Space,
        otherAxisDivides: Bool
    ) -> CommandResponse? {
        guard
            let run = tiler.runCovers[space.id]?.runs.first(where: {
                $0.shown.contains(focused)
            }) ?? unhidingRun(of: focused, in: space)
        else { return nil }
        return resizeInRun(
            focused,
            run: run,
            axis: axis,
            delta: delta,
            space: space,
            otherAxisDivides: otherAxisDivides
        )
    }

    /// The run `focused` sits in where its zone is laid by floor
    /// and weight but hides nothing, which no cover records — any
    /// such zone, a refusal's (#2774) or a corroborated floor's.
    private func unhidingRun(
        of focused: WindowID,
        in space: Space
    ) -> RunCover.Run? {
        guard let screen = TilingEngine.screen(for: space.id, in: state)
        else { return nil }
        let input = tiler.layoutInput(
            state: state,
            space: space,
            screen: screen
        )
        guard
            let zones = RunZone.zones(
                mode: space.mode,
                tiled: input.tiled,
                in: input.context
            ),
            let zone = zones.first(where: {
                $0.members.contains(focused)
            }),
            let run = zone.run(in: input.context)
        else { return nil }
        return RunCover.Run(zone: zone, run: run, in: input.context)
    }

    /// The write for `focused` inside `run` — the recorded one, or
    /// a BSP chain's own run, which shows every window when no
    /// cover records it (#2542).
    func resizeInRun(
        _ focused: WindowID,
        run: RunCover.Run,
        axis: String,
        delta: Double,
        space: Space,
        otherAxisDivides: Bool
    ) -> CommandResponse {
        let shown = Array(run.shown)
        guard shown.count > 1, let index = shown.firstIndex(of: focused)
        else {
            // A run showing one window has no share to move.
            refuseNothingToDivide(
                focused,
                otherAxisDivides: otherAxisDivides
            )
            return .fail("the focused window is alone in its run")
        }
        guard run.extra > 0 else {
            // Every shown window sits at its floor: nothing to
            // give or take without hiding a window.
            if delta < 0 {
                refuseShrinkAtMinimum(focused, axis: axis)
            } else {
                refuseGrowAtNeighborMinimum(
                    focused,
                    anchor: shown[index == 0 ? 1 : index - 1],
                    axis: axis
                )
            }
            return .fail("every shown window is at its minimum")
        }
        let weights = shown.map {
            max(space.stackWeights[$0] ?? 1, StackLayout.weightFloor)
        }
        // Floors are kept by the layout itself, so the step
        // divides the extra with no minimum of its own.
        let outcome = StackLayout.weightStep(
            weights: weights,
            at: index,
            delta: delta,
            span: Double(run.extra),
            minSizes: Array(repeating: 0, count: shown.count)
        )
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[focused] = outcome.value
        }
        return .ok()
    }
}
