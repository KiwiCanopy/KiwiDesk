/// Stack layout shared domain rules: weight domain, partition, and resize
/// math (#44, #67).
extension StackLayout {
    /// Renormalization floor applied when reading stack weight (#67).
    public static let weightFloor: Double = 0.05
    /// Clamp for resize command stored weights (#67).
    public static let weightRange: ClosedRange<Double> = 0.1...10

    /// Outcome of an interactive weight step (#933).
    public struct WeightStepOutcome: Equatable, Sendable {
        public let value: Double
        /// Shrink was truncated at stepped share's own minimum size.
        public let hitOwnMinimum: Bool
        /// Other index whose minimum size capped a grow.
        public let blockedByOther: Int?
    }

    /// Safety margin (pt) added to minimum size before deriving weight clamp
    /// (#925).
    public static let minSizeMargin: Double = 0.25

    /// Single authority for interactive weight step math (#67, #128).
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

    /// Per-share interactive weight step respecting individual size floors
    /// (#933, #677, #925).
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
            // Per other index: the largest total that keeps its
            // share at its own minimum — `maxColumnTotal`, the
            // same authority the layouts' cascade checks read,
            // so the cap and the check cannot drift (#67). The
            // tightest other index is the cap and the cue's
            // anchor.
            var maxTotal = Double.infinity
            for (offset, weight) in weights.enumerated()
            where offset != index {
                guard minSizes[offset] > 0 else { continue }
                let limit = maxColumnTotal(
                    smallestWeight: weight,
                    span: span,
                    minSize: minSizes[offset] + Self.minSizeMargin
                )
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

    /// Usable span after outer and inner gaps for weighted division
    /// (#933, #925).
    public static func weightedSpan(
        region: Double,
        outer: Double,
        innerGap: Double,
        count: Int
    ) -> Double {
        region - outer - innerGap * Double(max(count - 1, 0))
    }

    /// Largest weight total before smallest share drops below `minSize` (#67).
    public static func maxColumnTotal(
        smallestWeight: Double,
        span: Double,
        minSize: Double
    ) -> Double {
        guard minSize > 0 else { return .infinity }
        return smallestWeight * span / minSize
    }

    /// Master/stack partition of tiled windows (#67).
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

    /// Column (zone) of `partition` containing `member` (nil if not in
    /// windows).
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
