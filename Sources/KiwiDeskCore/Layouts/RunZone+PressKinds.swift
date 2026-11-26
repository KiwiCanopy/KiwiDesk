import CoreGraphics

/// The two presses `RunZone.press` answers without a length step of
/// the window's own (#2709): beside only sized mates, and the run's
/// weight step.
extension RunZone {
    /// Who takes the room a shrink along the zone gives up.
    public enum ShrinkTaker: Sendable, Equatable {
        /// A shown mate draws wider.
        case shownMate
        /// The lone window gives way and the next one comes back.
        case waitingWindow
    }

    /// Who takes a shrink of `id` along the zone; nil where none
    /// does: `id` is not shown, the zone piles or draws its fixed
    /// cells, or `id` is alone with nobody waiting. The mouse drop's
    /// outer-edge filter and `press`'s pull both read it (#2970); it
    /// says nothing of whether a next window fits, which `press`
    /// answers with its refusal.
    public func shrinkTaker(
        of id: WindowID,
        in context: LayoutContext
    ) -> ShrinkTaker? {
        guard let index = members.firstIndex(of: id),
            !piles(in: context), !drawsSlots(in: context)
        else { return nil }
        guard let run = run(in: context) else {
            return members.count > 1 ? .shownMate : nil
        }
        return run.visible.contains(index) ? shrinkTaker(shown: run) : nil
    }

    /// `shrinkTaker(of:in:)` for a member `run` shows.
    func shrinkTaker(shown run: ZoneRun) -> ShrinkTaker? {
        if run.visible.count > 1 { return .shownMate }
        return run.hides ? .waitingWindow : nil
    }

    /// The press of the one window that draws what sized mates leave:
    /// the nearest mate's length moves the other way, and a grow past
    /// what that mate can give sets it to its floor and pushes on.
    func besideSized(
        _ line: Line,
        _ index: Int,
        by delta: CGFloat,
        toward side: PushSide
    ) -> Press {
        guard let mate = nearestSized(line, index, toward: side)
        else { return Press(cue: .nothingToDivide, refusal: .alone) }
        let member = members[mate]
        var press = Press()
        // A length replaces the weight (`lengths`).
        if line.weights[index] != 1 { press.weight = 1 }
        // The window holds what it now draws as well, so the shown
        // lengths keep filling the zone and the run still hides what
        // the push hid, however far the mate gives way.
        if delta < 0 {
            let room = line.drawn[index] - line.bare[index]
            let give = min(-delta, room)
            // A step within the room moves, however small.
            guard room > Self.unchangedTolerance || -delta <= room else {
                return Press(cue: .ownMinimum, refusal: .atMinimum)
            }
            if give < -delta - Self.unchangedTolerance {
                press.cue = .ownMinimum
            }
            press.sizes[member] = share(of: line.drawn[mate] + give)
            press.sizes[members[index]] = share(of: line.drawn[index] - give)
            return press
        }
        let room = line.drawn[mate] - line.bare[mate]
        guard delta > room else {
            press.sizes[member] = share(of: line.drawn[mate] - delta)
            press.sizes[members[index]] = share(of: line.drawn[index] + delta)
            return press
        }
        var given = line
        given.floors[mate] = line.bare[mate]
        given.drawn[mate] = line.bare[mate]
        given.drawn[index] += room
        let push = lengthStep(given, index, by: delta - room, toward: side)
        press.sizes[member] = .some(
            push.visible.contains(mate) ? share(of: line.bare[mate]) : nil
        )
        press.sizes[members[index]] = share(of: push.target)
        press.visible = push.visible
        press.movesRun = true
        return press
    }

    /// The step a press takes: as asked, or for a grow at its weight's
    /// limit in a run hiding nothing, far enough to push. No weight can
    /// grow the window, so the press is the one way on (#2709), whatever
    /// the mates have left above their floors.
    func pushingPastSpentWeight(
        _ line: Line,
        _ index: Int,
        by delta: CGFloat
    ) -> CGFloat {
        // A run that hides a window holds a length instead.
        guard delta > 0, line.before.count == members.count,
            members.count > 1,
            StackLayout.weightSpent(line.weights[index], by: Double(delta))
        else { return delta }
        return pushDistance(line, index, by: delta)
    }

    /// A grow far enough to push: past what the shown mates have
    /// left above their floors.
    func pushDistance(
        _ line: Line,
        _ index: Int,
        by delta: CGFloat
    ) -> CGFloat {
        let others = line.before.filter { $0 != index }
        let slack =
            line.span - line.gap * CGFloat(others.count)
            - others.reduce(CGFloat(0)) { $0 + line.floors[$1] }
            - line.drawn[index]
        return max(delta, slack + 1)
    }

    /// The sized mate a press beside only sized mates moves.
    private func nearestSized(
        _ line: Line,
        _ index: Int,
        toward side: PushSide
    ) -> Int? {
        let sized = line.before.filter {
            $0 != index && line.weights[$0] == 0
        }
        let ahead = sized.filter { $0 < index }.max()
        let after = sized.filter { $0 > index }.min()
        return side == .start ? ahead ?? after : after ?? ahead
    }

    /// The write that takes `id` to the point a push would begin, the
    /// run unmoved: where a hold stops, since only a press pushes
    /// (#2709). Nil where the run hides nothing, which holds no length.
    public func stopShortOfPush(
        _ id: WindowID,
        toward side: PushSide,
        in context: LayoutContext
    ) -> Press? {
        guard let index = members.firstIndex(of: id),
            let run = run(in: context), run.hides,
            run.visible.contains(index)
        else { return nil }
        let line = line(in: context)
        let others = run.visible.filter { $0 != index }
        var floors = line.floors
        var press = Press()
        if line.weights[index] > 0,
            others.allSatisfy({ line.weights[$0] == 0 }),
            let mate = nearestSized(line, index, toward: side)
        {
            floors[mate] = line.bare[mate]
            press.sizes[members[mate]] = share(of: line.bare[mate])
        }
        for other in others
        where line.weights[other] > 0
            && line.held[other] > line.bare[other]
        {
            press.sizes[members[other]] = share(of: line.bare[other])
        }
        let rest =
            line.span - line.gap * CGFloat(others.count)
            - others.reduce(CGFloat(0)) { $0 + floors[$1] }
        guard rest >= line.bare[index] else { return nil }
        press.sizes[id] = share(of: rest)
        if plainWeight(of: id, in: context) != 1 { press.weight = 1 }
        press.visible = run.visible
        return press
    }

    /// The refusal of a weight at its limit, cued on a shrink as the
    /// window's own floor where it draws at it, since a floor wins
    /// over the limit (#3643).
    func limitPress(
        _ line: Line,
        _ index: Int,
        by delta: CGFloat
    ) -> Press {
        let floored =
            delta < 0
            && line.drawn[index] <= line.bare[index] + Self.unchangedTolerance
        return Press(
            cue: floored ? .ownMinimum : .weightLimit,
            refusal: .atWeightLimit
        )
    }

    /// The run's weight step (#2235): it divides the span the shown
    /// windows' floors leave, among the windows that take a share,
    /// with no minimum of its own, since the layout keeps the floors.
    /// Nil where no weight moves the window the way the press asks
    /// (`checkedWeight`).
    func weightStep(
        _ line: Line,
        _ index: Int,
        shown: [Int],
        by delta: CGFloat,
        in context: LayoutContext
    ) -> Press? {
        guard shown.count > 1, let at = shown.firstIndex(of: index) else {
            return Press(cue: .nothingToDivide, refusal: .alone)
        }
        let extra = runExtra(in: context) ?? 0
        guard extra > 0 else {
            let anchor = members[shown[StackLayout.nearestMate(of: at)]]
            return Press(
                cue: delta < 0 ? .ownMinimum : .neighborMinimum(anchor),
                refusal: .atMinimum
            )
        }
        let stepped = StackLayout.weightStep(
            weights: shown.map { line.weights[$0] },
            at: at,
            delta: Double(delta),
            span: Double(extra),
            minSizes: Array(repeating: 0, count: shown.count)
        ).value
        guard
            let weight = checkedWeight(
                stepped,
                line,
                index,
                by: delta,
                in: context
            )
        else { return nil }
        var press = Press()
        press.weight = weight
        return press
    }

    /// `stepped` where it keeps the render's split and moves the
    /// window, else the weight that moves the window the way `delta`
    /// presses, nearest the length asked; nil where none does. A step
    /// that flips the split between whole and floor-and-share redraws
    /// every share, which can move the window the other way (#2967),
    /// and a step clamped at the weight's limit can move it by less
    /// than the screen shows (#3634). A nil for a run that still
    /// hides means the weight's limit, which `press` answers with a
    /// length step. A whole-zone writer's floors keep its own step
    /// from crossing (state-and-layout.md).
    private func checkedWeight(
        _ stepped: Double,
        _ line: Line,
        _ index: Int,
        by delta: CGFloat,
        in context: LayoutContext
    ) -> Double? {
        let id = members[index]
        var trial = context
        trial.stackWeights[id] = stepped
        let drawn = line.drawn[index]
        let sense: CGFloat = delta < 0 ? -1 : 1
        guard run(in: trial) == nil else {
            let moved = drawnLength(of: id, weight: stepped, in: context)
            return (moved - drawn) * sense > Self.unchangedTolerance
                ? stepped : nil
        }
        let target = drawn + delta
        return
            ([stepped]
            + weightCandidates(
                for: id,
                at: target,
                floor: line.bare[index],
                in: context
            ))
            .map { ($0, drawnLength(of: id, weight: $0, in: context)) }
            .filter { ($0.1 - drawn) * sense > Self.unchangedTolerance }
            .min { abs($0.1 - target) < abs($1.1 - target) }?.0
    }
}
