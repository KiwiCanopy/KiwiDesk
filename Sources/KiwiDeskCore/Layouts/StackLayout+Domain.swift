/// The stack layout's shared domain rules (#44/#67), split from
/// `StackLayout` for file size (AGENTS.md §2): the weight
/// domain, the master/stack partition, and the effective-ratio
/// authorities consumed by both the layout math and the
/// interactive resize paths — single sources so the write side
/// and the render side cannot drift apart (parity rule).
extension StackLayout {
    /// Renormalization floor applied when *reading* a stack
    /// weight (#67) — shared with the `resize` command so the
    /// command's step math and the layout's distribution can
    /// never disagree on the domain. Deliberately below
    /// `weightRange.lowerBound`: the command never stores a
    /// value this small, so the floor only defends against a
    /// future writer — do not collapse the two constants.
    public static let weightFloor: Double = 0.05
    /// Clamp for what the `resize` command *stores* (#67).
    public static let weightRange: ClosedRange<Double> = 0.1...10

    /// The master_ratio interval that keeps BOTH zones at
    /// least `minSize` wide within `available` points (#44),
    /// or nil when two min-size zones cannot coexist at any
    /// ratio — the cascade case. `minSize` ≤ 0 (or NaN) means
    /// no minimum: the full 0...1, which also fences nonsense
    /// stored ratios away from negative zone widths. The
    /// single authority behind the layout's effective clamp
    /// and the interactive write cap (parity rule).
    public static func effectiveRatioRange(
        available: Double,
        minSize: Double
    ) -> ClosedRange<Double>? {
        // A degenerate region (gaps wider than the usable
        // area) cascades regardless of the minimum.
        guard available > 0 else { return nil }
        guard minSize > 0 else { return 0...1 }
        guard available >= minSize * 2 else { return nil }
        let fraction = minSize / available
        return fraction...(1 - fraction)
    }

    /// Caps an interactive master_ratio write at the current
    /// display's effective range (#44): past it the layout
    /// clamps anyway and the stored value would only ratchet
    /// invisibly — the same rule as the #67 weight cap. Never
    /// pushes the value back across `base`, so an already
    /// out-of-range value stays editable in the direction
    /// that re-enters the range. (The config verb
    /// `stack.set_master_ratio` deliberately stays wide: the
    /// stored value is honored again on a wider display.)
    ///
    /// Call sites pass the raw screen span as `available` —
    /// a superset of the layout's gap-adjusted range, so the
    /// cap can never block reaching the visible bound; the
    /// residual overshoot is bounded by gaps/width (a few
    /// percent). On a display too narrow to split at all
    /// (range nil) the write is deliberately not capped:
    /// there is no visible bound to stop at, and the value
    /// stays editable for a wider display, bounded by the
    /// 0.1…0.9 store clamp. Callers must pass the SAME
    /// `minSize` the layout resolves (the global today) — a
    /// future per-space min_window_size override must reach
    /// both sides, or cap and clamp silently diverge.
    public static func cappedRatioWrite(
        _ proposed: Double,
        base: Double,
        available: Double,
        minSize: Double
    ) -> Double {
        guard
            let range = effectiveRatioRange(
                available: available,
                minSize: minSize
            )
        else { return proposed }
        if proposed > base {
            return min(proposed, max(range.upperBound, base))
        }
        if proposed < base {
            return max(proposed, min(range.lowerBound, base))
        }
        return proposed
    }

    /// One interactive weight step (#67/#128): the new value
    /// for `weights[index]` after a `resize` of `delta` points
    /// over a span of `span`. The single authority for the
    /// step math shared by the stack's `"y"` path and both
    /// track knobs — with heights h = A·w/W, dh/dw =
    /// A·(W−w)/W², so the exact step for dh = delta is
    /// dw = delta·W²/(A·(W−w)). Growing is capped where the
    /// smallest OTHER share would drop below `minSize` (past
    /// that cliff the layout cascades and extra weight only
    /// ratchets invisibly), never forced below the current
    /// value so an overflowed group stays editable downwards;
    /// the result clamps to `weightRange`. Callers pass
    /// already-floored weights (`weightFloor`).
    public static func weightStep(
        weights: [Double],
        at index: Int,
        delta: Double,
        span: Double,
        minSize: Double
    ) -> Double {
        let current = weights[index]
        let total = weights.reduce(0, +)
        let change =
            delta * total * total / (span * (total - current))
        var value = current + change
        if change > 0 {
            let others = weights.enumerated()
                .filter { $0.offset != index }
                .map(\.element)
            if let smallest = others.min() {
                let limit = maxColumnTotal(
                    smallestWeight: smallest,
                    height: span,
                    minSize: minSize
                )
                let cap = limit - (total - current)
                value = min(value, max(cap, current))
            }
        }
        return min(
            max(value, weightRange.lowerBound),
            weightRange.upperBound
        )
    }

    /// The largest weight total a column can carry before its
    /// smallest share drops below `minSize` — the single
    /// authority behind both the layout's cascade check and
    /// the resize command's growth cap, so the two formulas
    /// cannot drift apart (#67 review; parity rule).
    public static func maxColumnTotal(
        smallestWeight: Double,
        height: Double,
        minSize: Double
    ) -> Double {
        // No (or nonsense) minimum → no cliff, matching the
        // old `share < minSize` comparison for minSize ≤ 0.
        guard minSize > 0 else { return .infinity }
        return smallestWeight * height / minSize
    }

    /// The master/stack partition of a tiled window array —
    /// the single authority consumed by `calculateGeometry`
    /// and the `resize` command (#67 review: a third
    /// hand-mirror of this rule had crept in). `stack` is nil
    /// while everything still fits in the master zone.
    public static func partition(
        _ windows: [WindowID],
        masterCount: Int
    ) -> (
        master: ArraySlice<WindowID>,
        stack: ArraySlice<WindowID>?
    ) {
        let boundary = max(1, masterCount)
        guard windows.count > boundary else {
            return (windows[...], nil)
        }
        return (windows[..<boundary], windows[boundary...])
    }

    /// The column (zone) of `partition` holding `member`, or
    /// nil when it is not in `windows`.
    public static func column(
        containing member: WindowID,
        in windows: [WindowID],
        masterCount: Int
    ) -> ArraySlice<WindowID>? {
        guard let index = windows.firstIndex(of: member) else {
            return nil
        }
        let (master, stack) = partition(
            windows,
            masterCount: masterCount
        )
        guard let stack, index >= master.endIndex else {
            return master
        }
        return stack
    }
}
