/// Weight feasibility reconciliation operations (`weightedSpan`, #944).
extension StackLayout {
    /// Reconciles stored weights to fit current membership and
    /// span (#944; `maxColumnTotal`, `minSizeMargin`, #925/#933).
    /// Nil when nothing needs healing — no margin: a stored value
    /// between the margined clamp target and the raw check still
    /// renders, and shaving it would rewrite a legal weight — and
    /// nil when no weights can fit: that pile is honest physics.
    /// Only weights above the waterline cap are shaved.
    public static func healedWeights(
        weights: [Double],
        span: Double,
        minSize: Double
    ) -> [Double]? {
        guard weights.count > 1, minSize > 0, span > 0,
            let smallest = weights.min()
        else { return nil }
        let total = weights.reduce(0, +)
        guard
            total
                > maxColumnTotal(
                    smallestWeight: smallest,
                    span: span,
                    minSize: minSize
                )
        else { return nil }
        let target = maxColumnTotal(
            smallestWeight: smallest,
            span: span,
            minSize: minSize + minSizeMargin
        )
        // A cap can only lower weights toward the smallest, so
        // the capped total can never drop below count × smallest
        // — a target under that is unreachable: the span holds
        // fewer than `count` minimums whatever the weights say.
        guard target >= Double(weights.count) * smallest else {
            return nil
        }
        // Waterline: the largest cap with Σ min(w, cap) ==
        // target. Ascending walk — at each weight, the cap that
        // spends the remaining budget on every not-yet-passed
        // member; the first candidate at or below the current
        // weight is the answer.
        let sorted = weights.sorted()
        var kept = 0.0
        var cap = target
        for (index, weight) in sorted.enumerated() {
            let above = Double(sorted.count - index)
            cap = (target - kept) / above
            if cap <= weight { break }
            kept += weight
        }
        return weights.map { Swift.min($0, cap) }
    }
}
