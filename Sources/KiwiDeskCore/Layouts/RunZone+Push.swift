import CoreGraphics

/// A resize along a run's scroll direction (#2709 ruling): a grow
/// past what the shown neighbours can give pushes the neighbour it
/// squeezes into the run, and a shrink pulls waiting windows back
/// while the next one fits at its floor. The run stays contiguous,
/// so the window that leaves or returns sits at one of its ends.
/// Pure; the capped writers write what it answers.
extension RunZone {
    /// The side of the resized window a gesture moves: the edge a
    /// mouse drag moved, measured from the drawn frame, or both
    /// for the keyboard `resize`, which steps from the length the
    /// run plans — a lone shown window draws the whole zone, so
    /// repeated shrinks there still add up.
    public enum PushSide: Sendable, Equatable {
        case start, end, both
    }

    /// What a resize along the run leaves.
    public struct Resize: Sendable, Equatable {
        /// The resized member's new `Space.runSizes` entry, in
        /// points along the zone's axis.
        public let size: CGFloat
        /// Members shown after the write, in member indices.
        public let visible: Range<Int>
        /// Whether the shrink stopped at the member's own floor.
        public let atOwnMinimum: Bool
        /// Whether anything moved: the member's extent or the run.
        public let changed: Bool
    }

    /// The run `id` ends in after growing by `delta` points along
    /// the zone's axis (negative shrinks), moving the edge on
    /// `side`. A grow drops the member at the pushed end, `.both`
    /// the last in order first (ruling 2); a shrink brings back
    /// the window waiting past the moved edge, `.both` the one
    /// after the run first, then the other end's once that side
    /// has none waiting, stopping at the first that does not fit
    /// (ruling 4). Nil where `id` is not shown in this zone.
    public func resize(
        _ id: WindowID,
        by delta: CGFloat,
        toward side: PushSide,
        in context: LayoutContext
    ) -> Resize? {
        guard let index = members.firstIndex(of: id) else { return nil }
        let before = run(in: context)?.visible ?? members.indices
        guard before.contains(index),
            let drawn = frames(in: context)[id].map(length)
        else { return nil }
        let extent =
            side == .both ? context.runSizes[id] ?? drawn : drawn
        let (floors, bare, gap) = floorsAndGap(in: context)
        let span = length(region)
        let own = bare[index]
        let target = min(max(extent + delta, own), span)
        var start = before.lowerBound
        var last = before.upperBound - 1
        func fits(_ first: Int, _ end: Int) -> Bool {
            let others = (first...end).reduce(CGFloat(0)) {
                $1 == index ? $0 : $0 + floors[$1]
            }
            return target + others + gap * CGFloat(end - first)
                <= span + Self.pushTolerance
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
        } else if delta < 0 {
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
        return Resize(
            size: target,
            visible: visible,
            atOwnMinimum: delta < 0 && extent + delta < own,
            changed: visible != before
                || abs(target - extent) > Self.pushTolerance
        )
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

    /// A point of slack on the fit, so a frame rounded by the
    /// layout neither pushes nor refuses a window it holds.
    static let pushTolerance: CGFloat = 0.5

    private func length(_ rect: CGRect) -> CGFloat {
        vertical ? rect.height : rect.width
    }
}
