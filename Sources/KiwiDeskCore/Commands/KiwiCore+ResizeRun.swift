import Foundation

/// A resize along a zone's scroll direction (#2235, #2709): the
/// writers store what the one pure `RunZone.press` answers — a
/// weight step, a push, a pull or a mate's length — and cue its
/// refusal, for every layout that scrolls a run.
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
        // A weight already at its limit moves nothing, and a silent
        // press never ends a hold.
        let spent =
            members.count > 1
            && StackLayout.weightSpent(
                space.stackWeights[focused] ?? 1,
                by: delta
            )
        let at = members.firstIndex(of: focused) ?? 0
        if delta < 0, outcome.hitOwnMinimum || spent {
            // A limit above the floor is no minimum: a hold just ends.
            if outcome.hitOwnMinimum || !endGlideStep() {
                refuseShrinkAtMinimum(focused, axis: axis)
            }
        } else if delta > 0,
            let blocked = outcome.blockedByOther
                ?? (spent ? StackLayout.nearestMate(of: at) : nil)
        {
            if space.windows.contains(focused),
                let found = runZone(of: focused, axis: axis, in: space),
                let press = found.zone.press(
                    focused,
                    by: CGFloat(delta),
                    toward: side,
                    in: found.context
                ),
                press.movesRun
            {
                // A zone that fits whole holds no length, so the
                // caller's capped weight is where a hold stops.
                if endGlideStep() { return false }
                store(press, of: focused, in: found.zone, space: space)
                return true
            }
            if endGlideStep() { return false }
            refuseGrowAtNeighborMinimum(
                focused,
                anchor: members[blocked],
                axis: axis
            )
        }
        return false
    }

    /// The write for `window` in a BSP chain or a Grid's last track
    /// that fits whole, sharing its line by weight alone: the Stack
    /// zone writer's step (`resizeStackMember`), a grow its floors
    /// stop pushing into the run through `pushOrCue`.
    func resizeFittingZone(
        _ window: WindowID,
        zone: RunZone,
        context: LayoutContext,
        axis: String,
        delta: Double,
        toward side: RunZone.PushSide,
        space: Space
    ) -> CommandResponse {
        guard space.windows.contains(window) else {
            return .fail(
                "the focused window is visiting from "
                    + "another Space"
            )
        }
        guard let index = zone.members.firstIndex(of: window) else {
            return .fail("no focused tiled window")
        }
        let gap =
            zone.vertical
            ? context.gaps.inner.vertical : context.gaps.inner.horizontal
        let outcome = StackLayout.weightStep(
            weights: zone.members.map {
                max(space.stackWeights[$0] ?? 1, StackLayout.weightFloor)
            },
            at: index,
            delta: delta,
            span: Double(zone.span - gap * CGFloat(zone.members.count - 1)),
            minSizes: zone.members.map {
                plannedMinSize(of: $0, axis: axis)
            }
        )
        if pushOrCue(
            outcome,
            of: window,
            members: zone.members,
            axis: axis,
            delta: delta,
            toward: side,
            space: space
        ) {
            return .ok()
        }
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[window] = outcome.value
        }
        return .ok()
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
            let press = zone.press(
                focused,
                by: CGFloat(delta),
                toward: side,
                in: context
            )
        else {
            refuseNothingToDivide(
                focused,
                otherAxisDivides: otherAxisDivides
            )
            return .fail("the focused window is alone in its run")
        }
        if delta > 0, press.movesRun, endGlideStep() {
            if let stop = zone.stopShortOfPush(
                focused,
                toward: side,
                in: context
            ) {
                store(stop, of: focused, in: zone, space: space)
            }
            return .ok()
        }
        // A limit above the floor is no minimum: a hold just ends.
        if press.refusal == .atWeightLimit, endGlideStep() {
            return .ok()
        }
        switch press.cue {
        case .ownMinimum:
            refuseShrinkAtMinimum(focused, axis: axis)
        case .neighborMinimum(let anchor):
            refuseGrowAtNeighborMinimum(focused, anchor: anchor, axis: axis)
        case .nothingToDivide:
            refuseNothingToDivide(
                focused,
                otherAxisDivides: otherAxisDivides
            )
        case nil:
            break
        }
        switch press.refusal {
        case .alone:
            return .fail("the focused window is alone in its run")
        case .atMinimum:
            return .fail("every shown window is at its minimum")
        case .atWeightLimit:
            return .fail("the window's share is at its limit")
        case nil:
            store(press, of: focused, in: zone, space: space)
            return .ok()
        }
    }

    /// During a glide step, ends the hold with no cue; true when it
    /// did. Only a press pushes (#2709), so a hold cannot hide windows
    /// faster than they can be pulled back, and stopping there is no
    /// refusal.
    private func endGlideStep() -> Bool {
        guard keys.isApplyingGlideStep else { return false }
        keys.endGlide()
        return true
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

    /// Stores what `press` answers in one write: the weight, every
    /// length it sets or clears, and the run's two ends with them,
    /// so the next pass draws the run the press planned.
    private func store(
        _ press: RunZone.Press,
        of focused: WindowID,
        in zone: RunZone,
        space: Space
    ) {
        state.workspaces.withSpace(space.id) {
            if let weight = press.weight {
                $0.stackWeights[focused] = weight
            }
            for (member, share) in press.sizes {
                $0.runSizes[member] = share.map {
                    RunSize(share: $0, zone: zone.ordinal)
                }
            }
            if let visible = press.visible {
                ($0.runHeads, $0.runTails) = zone.ends(
                    showing: visible,
                    heads: $0.runHeads,
                    tails: $0.runTails
                )
            }
        }
    }
}
