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

    /// What one interactive weight step did besides the value:
    /// whether a shrink stopped at the stepped share's own
    /// minimum, and which OTHER index's minimum capped a grow —
    /// the inputs the refusal cues render (#933). `nil`
    /// `blockedByOther` with an unchanged value on a grow means
    /// only the store clamp (`weightRange`) engaged, which is a
    /// domain bound, not a size limit — no cue.
    public struct WeightStepOutcome: Equatable, Sendable {
        public let value: Double
        /// A shrink was truncated at the stepped share's own
        /// minimum size (fires on the first attempt that LANDS
        /// on the minimum, not only once already there).
        public let hitOwnMinimum: Bool
        /// The other index whose minimum size capped a grow.
        public let blockedByOther: Int?
    }

    /// Safety margin (pt) added to a minimum before deriving
    /// its weight clamp. The layout's cascade check
    /// (`maxColumnTotal` over the SAME span) sits at exact
    /// equality with the clamp's fixed point, so float rounding
    /// alone could tip a clamped-at-minimum write over the
    /// cliff into an `OverlapStack` pile — the #925 failure
    /// one epsilon wide. A quarter point is invisible on
    /// screen and decisively inside the guard.
    public static let minSizeMargin: Double = 0.25

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
        weightStep(
            weights: weights,
            at: index,
            delta: delta,
            span: span,
            minSizes: Array(
                repeating: minSize,
                count: weights.count
            )
        ).value
    }

    /// The per-share form of `weightStep` (#933): `minSizes`
    /// carries each index's own effective minimum (the global
    /// `min_window_size` raised by that window's learned
    /// app-enforced bound, #677), so a shrink clamps at the
    /// stepped window's own floor while a grow caps where the
    /// FIRST other share would drop below ITS floor — the two
    /// directions read different windows' minimums, which the
    /// single-`minSize` form cannot express. Callers pass the
    /// span the layout actually divides (gap-adjusted); a raw
    /// region span lets the stored value cross the layout's
    /// cascade check by exactly the gaps (#925's residue).
    public static func weightStep(
        weights: [Double],
        at index: Int,
        delta: Double,
        span: Double,
        minSizes: [Double]
    ) -> WeightStepOutcome {
        let current = weights[index]
        let total = weights.reduce(0, +)
        let otherTotal = total - current
        let change =
            delta * total * total / (span * otherTotal)
        var value = current + change
        var hitOwnMinimum = false
        var blockedByOther: Int? = nil
        if change > 0 {
            // total ≤ wᵢ·span/mᵢ keeps other share i at least
            // mᵢ; the tightest other index is the cap and the
            // cue's anchor.
            var maxTotal = Double.infinity
            for (offset, weight) in weights.enumerated()
            where offset != index {
                let min = minSizes[offset] + Self.minSizeMargin
                guard minSizes[offset] > 0 else { continue }
                let limit = weight * span / min
                if limit < maxTotal {
                    maxTotal = limit
                    blockedByOther = offset
                }
            }
            let cap = maxTotal - otherTotal
            if value > max(cap, current) {
                value = max(cap, current)
            } else {
                blockedByOther = nil
            }
        } else if change < 0 {
            let min = minSizes[index] + Self.minSizeMargin
            if minSizes[index] > 0, span > min, otherTotal > 0 {
                let minWeight =
                    min * otherTotal / (span - min)
                let floor = Swift.min(minWeight, current)
                if value < floor {
                    value = floor
                    hitOwnMinimum = true
                }
            }
        }
        return WeightStepOutcome(
            value: Swift.min(
                Swift.max(value, weightRange.lowerBound),
                weightRange.upperBound
            ),
            hitOwnMinimum: hitOwnMinimum,
            blockedByOther: blockedByOther
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
