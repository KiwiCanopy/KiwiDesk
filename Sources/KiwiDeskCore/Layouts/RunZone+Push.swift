import CoreGraphics

/// A press along a run's scroll direction (#2709 ruling): the one
/// answer every capped writer takes. A grow past what the shown
/// neighbours can give pushes the neighbour it squeezes into the
/// run; a lone window's shrink brings the next one back at its floor;
/// a window beside only sized mates moves the nearest mate's length; any
/// other press is the run's weight step. The run stays contiguous,
/// so the window that leaves or returns sits at one of its ends.
/// Pure; the writers store what it answers.
extension RunZone {
    /// The side of the resized window a gesture moves: the edge a
    /// mouse drag moved, or both for the keyboard `resize`.
    public enum PushSide: Sendable, Equatable {
        case start, end, both
    }

    /// What a press along the run writes.
    public struct Press: Sendable, Equatable {
        public enum Cue: Sendable, Equatable {
            case ownMinimum
            case neighborMinimum(WindowID)
            case nothingToDivide
        }

        public enum Refusal: Sendable, Equatable {
            /// The window is the one shown and has no room to take.
            case alone
            /// Every shown window sits at its floor.
            case atMinimum
        }

        /// New `Space.runSizes` shares by window; nil clears one.
        public var sizes: [WindowID: CGFloat?] = [:]
        /// The pressed window's new `stackWeights` entry.
        public var weight: Double?
        /// The run the press leaves; nil keeps the stored ends.
        public var visible: Range<Int>?
        public var cue: Cue?
        /// Set where the press moved nothing.
        public var refusal: Refusal?
        /// Whether a window left or joined the shown run.
        public var movesRun = false
    }

    /// The answer for growing `id` by `delta` points along the zone's
    /// axis (negative shrinks), moving the edge on `side`. Nil where
    /// `id` is not shown, where the zone piles, or — for a zone that
    /// fits whole — where
    /// the grow moves no window into the run, and the caller then
    /// keeps its whole-zone step.
    public func press(
        _ id: WindowID,
        by delta: CGFloat,
        toward side: PushSide,
        in context: LayoutContext
    ) -> Press? {
        guard let index = members.firstIndex(of: id),
            !piles(in: context)
        else { return nil }
        let line = line(in: context)
        guard line.before.contains(index) else { return nil }
        guard let run = run(in: context) else {
            let step = lengthStep(line, index, by: delta, toward: side)
            return step.movesRun
                ? lengths(step, of: id, on: line, context) : nil
        }
        let shown = Array(run.visible)
        if shown.count > 1, line.weights[index] > 0,
            shown.allSatisfy({ $0 == index || line.weights[$0] == 0 })
        {
            return besideSized(line, index, by: delta, toward: side)
        }
        let step = lengthStep(
            line,
            index,
            by: delta,
            toward: side,
            pulls: shown.count == 1
        )
        let spent = weightSpent(line.weights[index], by: delta)
        if step.movesRun || line.weights[index] == 0 || (spent && run.hides) {
            return lengths(step, of: id, on: line, context)
        }
        // A run that shows everyone holds no length, so a spent
        // weight stops here and says so: a silent press never ends
        // a hold.
        if spent, let at = shown.firstIndex(of: index) {
            return Press(
                cue: delta < 0
                    ? .ownMinimum
                    : .neighborMinimum(members[shown[at == 0 ? 1 : at - 1]]),
                refusal: .atMinimum
            )
        }
        return weightStep(line, index, shown: shown, by: delta, in: context)
    }

    /// Whether `weight` sits at the limit a press of `delta` moves
    /// it toward, where the weight step can move nothing.
    private func weightSpent(_ weight: Double, by delta: CGFloat) -> Bool {
        let range = StackLayout.weightRange
        return delta > 0
            ? weight >= range.upperBound : weight <= range.lowerBound
    }

    /// `heads` and `tails` with this zone's ends set to show
    /// `visible`, every other zone's left as stored — what a
    /// writer stores as `Space.runHeads` and `runTails`.
    public func ends(
        showing visible: Range<Int>,
        heads: Set<WindowID>,
        tails: Set<WindowID>
    ) -> (heads: Set<WindowID>, tails: Set<WindowID>) {
        var heads = heads.subtracting(members)
        var tails = tails.subtracting(members)
        if visible.lowerBound > 0 { heads.insert(members[visible.lowerBound]) }
        if visible.upperBound < members.count {
            tails.insert(members[visible.upperBound - 1])
        }
        return (heads, tails)
    }

    /// Below this many points a press moved nothing the screen
    /// shows.
    static let unchangedTolerance: CGFloat = 0.5

    /// The run as the render plans it: each member's planned, held
    /// (its stored length, even taking the rest) and bare length, its
    /// share weight and drawn length, the gap and the members shown.
    struct Line {
        var floors: [CGFloat]
        let held: [CGFloat]
        let bare: [CGFloat]
        let weights: [Double]
        var drawn: [CGFloat]
        let gap: CGFloat
        let span: CGFloat
        let before: Range<Int>
    }

    private func line(in context: LayoutContext) -> Line {
        let (floors, bare, gap) = floorsAndGap(in: context)
        let frames = frames(in: context)
        let sizes = honouredSizes(bare: bare, gap: gap, in: context)
        return Line(
            floors: floors,
            held: members.indices.map { sizes[$0] ?? bare[$0] },
            bare: bare,
            weights: shareWeights(in: context),
            drawn: members.map { frames[$0].map(length) ?? 0 },
            gap: gap,
            span: span,
            before: run(in: context)?.visible ?? members.indices
        )
    }

    struct LengthStep {
        let target: CGFloat
        let visible: Range<Int>
        let joined: [Int]
        let atOwnMinimum: Bool
        let changed: Bool
        let movesRun: Bool
    }

    /// The length step from what the window draws, as the scrolling
    /// slot steps (#1057), so nothing banks a length the screen does
    /// not show. A grow drops the member at the pushed end, `.both`
    /// the last in order first (ruling 2), and the grown window takes
    /// the pushed one's room; where `pulls` — a lone window, which
    /// always fills its zone — any shrink gives up what the window
    /// waiting past the moved edge needs at its floor and brings it
    /// back, `.both` the one after the run first, then the other
    /// end's once that side has none waiting, stopping at the first
    /// that does not fit (ruling 4). Any other shrink hands its room
    /// to the shown mates. A window that returns keeps no length.
    func lengthStep(
        _ line: Line,
        _ index: Int,
        by delta: CGFloat,
        toward side: PushSide,
        pulls: Bool = false
    ) -> LengthStep {
        let extent = line.drawn[index]
        let own = line.bare[index]
        var target = plannedLength(
            share: share(of: extent + delta),
            floor: own
        )
        var start = line.before.lowerBound
        var last = line.before.upperBound - 1
        var refused = false
        func fits(_ first: Int, _ end: Int) -> Bool {
            ZoneRun.fits(
                (first...end).map {
                    if $0 == index { return target }
                    return line.before.contains($0)
                        ? line.floors[$0] : line.bare[$0]
                },
                gap: line.gap,
                span: line.span
            )
        }
        if delta > 0 {
            while !fits(start, last) {
                let canEnd = last > index
                let canStart = start < index
                if canEnd, side != .start || !canStart {
                    last -= 1
                } else if canStart {
                    start += 1
                } else {
                    break
                }
            }
            if start..<(last + 1) != line.before {
                let kept = (start...last).filter { $0 != index }
                let room =
                    line.span - line.gap * CGFloat(kept.count)
                    - kept.reduce(CGFloat(0)) { $0 + line.drawn[$1] }
                let asked = target
                target = plannedLength(
                    share: share(of: max(target, room)),
                    floor: own
                )
                if !fits(start, last) { target = asked }
            }
        } else if delta < 0, pulls {
            func next() -> Int? {
                let after = last + 1 < members.count ? last + 1 : nil
                let ahead = start > 0 ? start - 1 : nil
                return side == .start ? ahead ?? after : after ?? ahead
            }
            // A lone window fills its zone, so any shrink gives up
            // what the next window needs at its floor: no room is
            // ever held open for nothing.
            if let waiting = next() {
                let margin = CGFloat(StackLayout.minSizeMargin)
                let room = line.span - line.gap - line.bare[waiting] - margin
                target = plannedLength(
                    share: share(of: min(target, room)),
                    floor: own
                )
            }
            while let waiting = next() {
                let grown = (min(start, waiting), max(last, waiting))
                guard fits(grown.0, grown.1) else { break }
                (start, last) = grown
            }
            if start..<(last + 1) == line.before {
                target = extent
                refused = true
            }
        }
        // A window holding a length that shrinks far enough for every
        // member to fit leaves no run: the render shows them all.
        if delta < 0, line.weights[index] == 0,
            ZoneRun.fits(
                members.indices.map {
                    if $0 == index { return target }
                    return line.before.contains($0)
                        ? line.floors[$0] : line.bare[$0]
                },
                gap: line.gap,
                span: line.span
            )
        {
            start = 0
            last = members.count - 1
        }
        let visible = start..<(last + 1)
        return LengthStep(
            target: target,
            visible: visible,
            joined: visible.filter { !line.before.contains($0) },
            atOwnMinimum: !refused && delta < 0 && extent + delta < own,
            changed: visible != line.before
                || abs(target - extent) > Self.unchangedTolerance,
            movesRun: visible != line.before
        )
    }

    /// A length answer: the window keeps the step's length, and a
    /// window a pull brings back returns at its floor and share. A
    /// pull that shows every member leaves no run to hold a length,
    /// so the window keeps it as the weight that draws it there.
    private func lengths(
        _ step: LengthStep,
        of id: WindowID,
        on line: Line,
        _ context: LayoutContext
    ) -> Press {
        var press = Press()
        if step.atOwnMinimum { press.cue = .ownMinimum }
        guard step.changed else {
            press.refusal = step.atOwnMinimum ? .atMinimum : .alone
            if !step.atOwnMinimum { press.cue = .nothingToDivide }
            return press
        }
        for joined in step.joined { press.sizes[members[joined]] = .some(nil) }
        if !step.joined.isEmpty, step.visible == members.indices {
            press.sizes[id] = .some(nil)
            for (at, weight) in line.weights.enumerated()
            where weight == 0 && members[at] != id {
                press.sizes[members[at]] = .some(nil)
            }
            press.weight = weight(
                drawing: id,
                at: step.target,
                floor: line.bare[members.firstIndex(of: id) ?? 0],
                in: context
            )
        } else {
            press.sizes[id] = share(of: step.target)
            // A length replaces the weight, which would otherwise
            // come back whenever the length stops being honoured.
            if plainWeight(of: id, in: context) != 1 { press.weight = 1 }
            // A window taking the rest holds what it will now draw,
            // or its old length would make the next pass hide it.
            let index = members.firstIndex(of: id)
            let shown = step.visible.filter { $0 != index }
            if let taker = shown.first(where: {
                line.weights[$0] > 0 && line.held[$0] > line.bare[$0]
            }) {
                let others = shown.filter { $0 != taker }
                let rest =
                    line.span - line.gap * CGFloat(shown.count) - step.target
                    - others.reduce(CGFloat(0)) { $0 + line.held[$1] }
                press.sizes[members[taker]] = share(
                    of: max(rest, line.bare[taker])
                )
            }
        }
        press.visible = step.visible
        press.movesRun = step.movesRun
        return press
    }

    private func length(_ rect: CGRect) -> CGFloat {
        vertical ? rect.height : rect.width
    }
}
