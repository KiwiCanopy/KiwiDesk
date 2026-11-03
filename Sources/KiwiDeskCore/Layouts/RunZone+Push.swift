import CoreGraphics

/// A press along a run's scroll direction (#2709 ruling): the one
/// answer every capped writer takes. A grow past what the shown
/// neighbours can give pushes the neighbour it squeezes into the
/// run; a window holding a push's length pulls waiting windows back
/// as it shrinks, while the next one fits at its floor; a window
/// beside only sized mates moves the nearest mate's length; any
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
    /// `id` is not shown, or — for a zone that fits whole — where
    /// the grow moves no window into the run, and the caller then
    /// keeps its whole-zone step.
    public func press(
        _ id: WindowID,
        by delta: CGFloat,
        toward side: PushSide,
        in context: LayoutContext
    ) -> Press? {
        guard let index = members.firstIndex(of: id),
            let line = line(in: context), line.before.contains(index)
        else { return nil }
        guard let run = run(in: context) else {
            let step = lengthStep(line, index, by: delta, toward: side)
            return step.movesRun ? lengths(step, of: id) : nil
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
            pulls: shown.count == 1 || line.weights[index] == 0
        )
        if step.movesRun || line.weights[index] == 0 {
            return lengths(step, of: id)
        }
        return weightStep(line, index, shown: shown, by: delta, in: context)
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

    /// The run as the render plans it: each member's planned and
    /// bare length, its share weight and drawn length, the gap and
    /// the members shown.
    private struct Line {
        var floors: [CGFloat]
        let bare: [CGFloat]
        let weights: [Double]
        var drawn: [CGFloat]
        let gap: CGFloat
        let span: CGFloat
        let before: Range<Int>
    }

    private func line(in context: LayoutContext) -> Line? {
        let (floors, bare, gap) = floorsAndGap(in: context)
        let frames = frames(in: context)
        return Line(
            floors: floors,
            bare: bare,
            weights: shareWeights(in: context),
            drawn: members.map { frames[$0].map(length) ?? 0 },
            gap: gap,
            span: span,
            before: run(in: context)?.visible ?? members.indices
        )
    }

    private struct LengthStep {
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
    /// the pushed one's room; where `pulls`, a shrink brings back the
    /// window waiting past the moved edge, `.both` the one after the
    /// run first, then the other end's once that side has none
    /// waiting, stopping at the first that does not fit (ruling 4).
    private func lengthStep(
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
        func fits(_ first: Int, _ end: Int) -> Bool {
            ZoneRun.fits(
                (first...end).map { $0 == index ? target : line.floors[$0] },
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
            while true {
                let after = last + 1 < members.count ? last + 1 : nil
                let ahead = start > 0 ? start - 1 : nil
                let next = side == .start ? ahead ?? after : after ?? ahead
                guard let next else { break }
                let grown = (min(start, next), max(last, next))
                guard fits(grown.0, grown.1) else { break }
                (start, last) = grown
            }
        }
        let visible = start..<(last + 1)
        return LengthStep(
            target: target,
            visible: visible,
            joined: visible.filter { !line.before.contains($0) },
            atOwnMinimum: delta < 0 && extent + delta < own,
            changed: visible != line.before
                || abs(target - extent) > Self.unchangedTolerance,
            movesRun: visible != line.before
        )
    }

    /// A length answer: the window keeps the step's length, and a
    /// window a pull brings back returns at its floor and share.
    private func lengths(_ step: LengthStep, of id: WindowID) -> Press {
        var press = Press()
        if step.atOwnMinimum { press.cue = .ownMinimum }
        guard step.changed else {
            press.refusal = step.atOwnMinimum ? .atMinimum : .alone
            if !step.atOwnMinimum { press.cue = .nothingToDivide }
            return press
        }
        for joined in step.joined { press.sizes[members[joined]] = .some(nil) }
        press.sizes[id] = share(of: step.target)
        press.visible = step.visible
        press.movesRun = step.movesRun
        return press
    }

    /// The press of the one window that draws what sized mates leave:
    /// the nearest mate's length moves the other way, and a grow past
    /// what that mate can give sets it to its floor and pushes on.
    private func besideSized(
        _ line: Line,
        _ index: Int,
        by delta: CGFloat,
        toward side: PushSide
    ) -> Press {
        let sized = line.before.filter {
            $0 != index && line.weights[$0] == 0
        }
        let ahead = sized.filter { $0 < index }.max()
        let after = sized.filter { $0 > index }.min()
        var press = Press()
        guard let mate = side == .start ? ahead ?? after : after ?? ahead
        else {
            press.refusal = .alone
            return press
        }
        let member = members[mate]
        // The window draws the rest, so it keeps no length of its own.
        press.sizes[members[index]] = .some(nil)
        if delta < 0 {
            let give = min(-delta, line.drawn[index] - line.bare[index])
            guard give > Self.unchangedTolerance else {
                return Press(cue: .ownMinimum, refusal: .atMinimum)
            }
            if give < -delta - Self.unchangedTolerance {
                press.cue = .ownMinimum
            }
            press.sizes[member] = share(of: line.drawn[mate] + give)
            return press
        }
        let room = line.drawn[mate] - line.bare[mate]
        guard delta > room else {
            press.sizes[member] = share(of: line.drawn[mate] - delta)
            return press
        }
        var given = line
        given.floors[mate] = line.bare[mate]
        given.drawn[mate] = line.bare[mate]
        given.drawn[index] += room
        let push = lengthStep(given, index, by: delta - room, toward: side)
        guard push.movesRun else {
            press.sizes[member] = share(of: line.bare[mate])
            press.cue = .neighborMinimum(member)
            return press
        }
        press.sizes[member] =
            push.visible.contains(mate) ? share(of: line.bare[mate]) : nil
        press.sizes[members[index]] = share(of: push.target)
        press.visible = push.visible
        press.movesRun = true
        return press
    }

    /// The run's weight step (#2235): it divides the span the shown
    /// windows' floors leave, among the windows that take a share,
    /// with no minimum of its own, since the layout keeps the floors.
    private func weightStep(
        _ line: Line,
        _ index: Int,
        shown: [Int],
        by delta: CGFloat,
        in context: LayoutContext
    ) -> Press {
        guard shown.count > 1, let at = shown.firstIndex(of: index) else {
            return Press(cue: .nothingToDivide, refusal: .alone)
        }
        let extra = runExtra(in: context) ?? 0
        guard extra > 0 else {
            let anchor = members[shown[at == 0 ? 1 : at - 1]]
            return Press(
                cue: delta < 0 ? .ownMinimum : .neighborMinimum(anchor),
                refusal: .atMinimum
            )
        }
        var press = Press()
        press.weight =
            StackLayout.weightStep(
                weights: shown.map { line.weights[$0] },
                at: at,
                delta: Double(delta),
                span: Double(extra),
                minSizes: Array(repeating: 0, count: shown.count)
            ).value
        return press
    }

    private func length(_ rect: CGRect) -> CGFloat {
        vertical ? rect.height : rect.width
    }
}
