import Foundation

/// A resize along a zone's scroll direction (#2235, #2709): the
/// layout gives every shown window its floor and divides only what
/// is left by weight (`ZoneRun.frames`), and a grow past what the
/// shown neighbours can give pushes the squeezed one into the run,
/// a shrink pulling waiting windows back — the one rule
/// `RunZone.resize` answers, for every layout that scrolls a run.
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
        toward side: RunZone.PushSide,
        space: Space,
        otherAxisDivides: Bool
    ) -> CommandResponse? {
        guard let found = runZone(of: focused, axis: axis, in: space),
            found.zone.run(in: found.context) != nil
        else { return nil }
        return resizeInRun(
            focused,
            zone: found.zone,
            context: found.context,
            axis: axis,
            delta: delta,
            toward: side,
            space: space,
            otherAxisDivides: otherAxisDivides
        )
    }

    /// The whole-zone weight step's cue (#933), or — for a grow a
    /// neighbour's floor stopped — that grow carried on along the
    /// zone's scroll direction (#2709), pushing the squeezed
    /// neighbour into the run where the floors no longer fit. True
    /// when the push wrote, and the caller then writes no weight.
    func pushOrCue(
        _ outcome: StackLayout.WeightStepOutcome,
        of focused: WindowID,
        members: [WindowID],
        axis: String,
        delta: Double,
        toward side: RunZone.PushSide,
        space: Space
    ) -> Bool {
        if delta < 0, outcome.hitOwnMinimum {
            refuseShrinkAtMinimum(focused, axis: axis)
        } else if delta > 0, let blocked = outcome.blockedByOther {
            if pushIntoRun(
                focused,
                axis: axis,
                delta: delta,
                toward: side,
                space: space
            ) {
                return true
            }
            refuseGrowAtNeighborMinimum(
                focused,
                anchor: members[blocked],
                axis: axis
            )
        }
        return false
    }

    /// The push `pushOrCue` carries a blocked grow on with; false
    /// where `focused` sits in no zone along `axis`, is visiting,
    /// or the grow moves no window into the run.
    private func pushIntoRun(
        _ focused: WindowID,
        axis: String,
        delta: Double,
        toward side: RunZone.PushSide,
        space: Space
    ) -> Bool {
        guard delta > 0, space.windows.contains(focused),
            let found = runZone(of: focused, axis: axis, in: space),
            let resize = found.zone.resize(
                focused,
                by: CGFloat(delta),
                toward: side,
                in: found.context
            ),
            resize.movesRun
        else { return false }
        write(
            resize,
            of: focused,
            in: found.zone,
            space: space
        )
        return true
    }

    /// The write for `focused` inside `zone`'s run — the zone a
    /// press finds, or a BSP chain's own (#2542).
    func resizeInRun(
        _ focused: WindowID,
        zone: RunZone,
        context: LayoutContext,
        axis: String,
        delta: Double,
        toward side: RunZone.PushSide,
        space: Space,
        otherAxisDivides: Bool
    ) -> CommandResponse {
        // A run-size entry under a visitor's id could never be
        // pruned (#308): its Space never removes it.
        guard space.windows.contains(focused) else {
            return .fail(
                "the focused window is visiting from "
                    + "another Space"
            )
        }
        guard
            let resize = zone.resize(
                focused,
                by: CGFloat(delta),
                toward: side,
                in: context
            ),
            let run = zone.run(in: context)
        else {
            refuseNothingToDivide(
                focused,
                otherAxisDivides: otherAxisDivides
            )
            return .fail("the focused window is alone in its run")
        }
        let weights = zone.shareWeights(in: context)
        let shown = Array(run.visible)
        guard let index = zone.members.firstIndex(of: focused) else {
            return .fail("no focused tiled window")
        }
        // Beside only sized mates the window draws what they leave,
        // so its press moves a mate's length the other way and the
        // push that mate made stands.
        if shown.count > 1, weights[index] > 0,
            shown.allSatisfy({ $0 == index || weights[$0] == 0 })
        {
            return resizeBesideSized(
                focused,
                at: index,
                zone: zone,
                context: context,
                axis: axis,
                delta: delta,
                toward: side,
                space: space
            )
        }
        // A push, a pull, or a window a push already sized takes a
        // length; any other press keeps the run's weight step.
        if resize.movesRun
            || zone.plannedSize(of: focused, in: context) != nil
        {
            if resize.atOwnMinimum {
                refuseShrinkAtMinimum(focused, axis: axis)
            }
            guard resize.changed else {
                if resize.atOwnMinimum {
                    return .fail("every shown window is at its minimum")
                }
                // A lone shown window fills the zone and has no
                // room left to grow into.
                refuseNothingToDivide(
                    focused,
                    otherAxisDivides: otherAxisDivides
                )
                return .fail("the focused window is alone in its run")
            }
            write(
                resize,
                of: focused,
                in: zone,
                space: space
            )
            return .ok()
        }
        return weighInRun(
            focused,
            shown: Array(zone.members[run.visible]),
            weights: Array(weights[run.visible]),
            extra: zone.runExtra(in: context) ?? 0,
            axis: axis,
            delta: delta,
            space: space,
            otherAxisDivides: otherAxisDivides
        )
    }

    /// A weight press inside a run that moves no window (#2235):
    /// the step divides the span the shown windows' floors leave,
    /// with no minimum of its own, since the layout keeps them.
    private func weighInRun(
        _ focused: WindowID,
        shown: [WindowID],
        weights: [Double],
        extra: CGFloat,
        axis: String,
        delta: Double,
        space: Space,
        otherAxisDivides: Bool
    ) -> CommandResponse {
        guard shown.count > 1, let index = shown.firstIndex(of: focused)
        else {
            refuseNothingToDivide(
                focused,
                otherAxisDivides: otherAxisDivides
            )
            return .fail("the focused window is alone in its run")
        }
        guard extra > 0 else {
            // Every shown window sits at its floor.
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
        // A sized mate draws no share (`RunZone.shareWeights`), so
        // the step divides only among the weighted ones.
        let outcome = StackLayout.weightStep(
            weights: weights,
            at: index,
            delta: delta,
            span: Double(extra),
            minSizes: Array(repeating: 0, count: shown.count)
        )
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[focused] = outcome.value
        }
        return .ok()
    }

    /// The zone `focused` sits in along `axis`, read from the
    /// render's own input.
    private func runZone(
        of focused: WindowID,
        axis: String,
        in space: Space
    ) -> (zone: RunZone, context: LayoutContext)? {
        guard let screen = TilingEngine.screen(for: space.id, in: state)
        else { return nil }
        let input = tiler.layoutInput(
            state: state,
            space: space,
            screen: screen
        )
        guard
            let zone = RunZone.zones(
                mode: space.mode,
                tiled: input.tiled,
                in: input.context
            )?.first(where: { $0.members.contains(focused) }),
            zone.vertical == (axis == "y")
        else { return nil }
        return (zone, input.context)
    }

    /// Stores the window's run size and the run's ends together,
    /// so the next pass draws the run the write planned. A window a
    /// pull brings back returns at its floor and share, so the
    /// shrunk window lands where it was asked on either side.
    func write(
        _ resize: RunZone.Resize,
        of focused: WindowID,
        in zone: RunZone,
        space: Space
    ) {
        state.workspaces.withSpace(space.id) {
            for member in resize.joined { $0.runSizes[member] = nil }
            $0.runSizes[focused] = RunSize(
                share: resize.size,
                zone: zone.members[0]
            )
            ($0.runHeads, $0.runTails) = zone.ends(
                showing: resize.visible,
                heads: $0.runHeads,
                tails: $0.runTails
            )
        }
    }

    /// Stores `length` points as `member`'s run size in `zone`.
    func writeLength(
        _ length: CGFloat,
        of member: WindowID,
        in zone: RunZone,
        space: Space
    ) {
        let span = zone.span
        guard span > 0 else { return }
        state.workspaces.withSpace(space.id) {
            $0.runSizes[member] = RunSize(
                share: length / span,
                zone: zone.members[0]
            )
        }
    }
}
