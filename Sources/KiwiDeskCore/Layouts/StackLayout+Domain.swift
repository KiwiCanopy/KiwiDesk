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
                    span: span,
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

    /// The largest weight total a zone can carry along its
    /// axis (`span`) before its smallest share drops below
    /// `minSize` — the single authority behind both the
    /// layout's cascade check and the resize command's growth
    /// cap, so the two formulas cannot drift apart (#67
    /// review; parity rule).
    public static func maxColumnTotal(
        smallestWeight: Double,
        span: Double,
        minSize: Double
    ) -> Double {
        // No (or nonsense) minimum → no cliff, matching the
        // old `share < minSize` comparison for minSize ≤ 0.
        guard minSize > 0 else { return .infinity }
        return smallestWeight * span / minSize
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
