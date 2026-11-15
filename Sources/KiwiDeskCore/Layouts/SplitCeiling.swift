import CoreGraphics

/// The ceiling twin of `SplitOverflow` (#3217, owner ruling
/// 2026-11-11): where every member of a split's side, a Stack
/// column or a Grid track has a learned maximum below its share,
/// that side yields the slack, down to its widest member's
/// ceiling, to a neighbour that can still grow. It runs on the
/// frames the retile ISSUES, never on the slots, so the stored
/// ratios and track weights are never written and the slack
/// returns the pass a ceiling is forgotten. A side holding any
/// window with no ceiling keeps its share; with no receiver the
/// gap stays. A forced pass probes past every ceiling (#1055).
/// Where no span moves, each arm answers nil and the slots stand,
/// so the pass never redraws a layout it leaves alone.
public enum SplitCeiling {
    /// `frames` with the ceiling slack shared out for `mode`:
    /// Stack, BSP and Grid; every other layout as it is.
    static func placed(
        mode: LayoutMode,
        windows: [WindowID],
        frames: [WindowID: CGRect],
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        guard !context.probesBeyondBounds, !context.sizeBounds.isEmpty
        else { return frames }
        let shared: [WindowID: CGRect]? =
            switch mode {
            case .stack: stack(windows, frames: frames, context)
            case .bsp: bsp(windows, frames: frames, context)
            case .grid: grid(windows, frames: frames, context)
            // Track heals its weights to its ceilings (#1488);
            // the others share no span between windows.
            case .track, .scrolling, .monocle, .floating: nil
            }
        return shared ?? frames
    }

    /// One container's ceiling along an axis: the widest of its
    /// members' learned maxima, nil where any member has none —
    /// that member can still grow, so the container keeps its
    /// share. Track's `trackCeiling` reads it too (#1488).
    static func ceiling(
        of members: some Sequence<WindowID>,
        horizontal: Bool,
        _ context: LayoutContext
    ) -> CGFloat? {
        var widest: CGFloat?
        for member in members {
            guard
                let ceiling = context.learnedCeiling(
                    of: member,
                    horizontal: horizontal
                )
            else { return nil }
            widest = max(widest ?? 0, ceiling)
        }
        return widest
    }

    /// `spans` with the slack redistributed, their sum kept: a
    /// span above its ceiling yields, a span below its ceiling (or
    /// with none) receives, filling the receivers in proportion to
    /// their spans up to their own ceilings. A yielder gives only
    /// what the receivers take, so nothing moves without one.
    public static func share(
        _ spans: [CGFloat],
        ceilings: [CGFloat?]
    ) -> [CGFloat] {
        let excess = zip(spans, ceilings).map { span, ceiling in
            ceiling.map { max(0, span - $0) } ?? 0
        }
        let slack = excess.reduce(0, +)
        guard slack > tolerance else { return spans }
        var result = spans
        var room = zip(spans, ceilings).map { span, ceiling in
            ceiling.map { max(0, $0 - span) } ?? .infinity
        }
        var left = slack
        // Water-fill: each round fills every open receiver by
        // span; one that reaches its ceiling closes. Bounded by
        // the receiver count.
        for _ in spans.indices {
            let open = result.indices.filter {
                excess[$0] == 0 && room[$0] > tolerance
            }
            let weight = open.reduce(0) { $0 + spans[$1] }
            guard left > tolerance, weight > 0 else { break }
            var given: CGFloat = 0
            for index in open {
                let take = min(room[index], left * spans[index] / weight)
                result[index] += take
                room[index] -= take
                given += take
            }
            left -= given
        }
        let taken = slack - max(0, left)
        guard taken > tolerance else { return spans }
        for index in result.indices where excess[index] > 0 {
            result[index] -= excess[index] * taken / slack
        }
        return result
    }

    /// `frames`, in drawn order along one axis, re-laid at
    /// `spans`: the first keeps its leading edge and every gap
    /// between neighbours is kept, so the sum fixes the trailing
    /// edge too.
    static func relaid(
        _ frames: [CGRect],
        spans: [CGFloat],
        horizontal: Bool
    ) -> [CGRect] {
        guard var edge = frames.first.map({ lead($0, horizontal) })
        else { return [] }
        return frames.indices.map { index in
            var frame = frames[index]
            if horizontal {
                frame.origin.x = edge
                frame.size.width = spans[index]
            } else {
                frame.origin.y = edge
                frame.size.height = spans[index]
            }
            if index + 1 < frames.count {
                let gap =
                    lead(frames[index + 1], horizontal)
                    - trail(frames[index], horizontal)
                edge += spans[index] + gap
            }
            return frame
        }
    }

    static func span(_ frame: CGRect, _ horizontal: Bool) -> CGFloat {
        horizontal ? frame.width : frame.height
    }

    static func lead(_ frame: CGRect, _ horizontal: Bool) -> CGFloat {
        horizontal ? frame.minX : frame.minY
    }

    static func trail(_ frame: CGRect, _ horizontal: Bool) -> CGFloat {
        horizontal ? frame.maxX : frame.maxY
    }

    /// Below this a slack is rounding, not a gap.
    static let tolerance: CGFloat = 0.5
}
