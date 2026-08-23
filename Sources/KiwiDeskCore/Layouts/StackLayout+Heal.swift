/// The session-weight feasibility heal (#944), beside the
/// domain authorities it derives from.
extension StackLayout {
    /// Heals a weighted group whose STORED weights no longer fit
    /// its CURRENT membership and span (#944): the write-time
    /// clamps (#933) validate a weight against the membership at
    /// press time, so a weight that was legal when written — the
    /// store ceiling is 10.0 — can, once a member JOINS the
    /// group (or the span shrinks), squeeze the smallest share
    /// below `minSize`, trip the layouts' cascade check
    /// (`maxColumnTotal`, the same authority) and collapse the
    /// whole group into an overlap pile.
    ///
    /// Returns nil when nothing needs healing — the total passes
    /// the layouts' own check (no margin: a stored value between
    /// the margined clamp target and the raw check still renders,
    /// and shaving it would rewrite a legal weight) — and nil
    /// when no weights can fit (the span is below the group's
    /// count × minimum): that pile is honest physics and stays
    /// with the overflow folds. Otherwise the healed array: a
    /// waterline cap `c` chosen so the capped total lands the
    /// smallest share exactly at `minSize + minSizeMargin` —
    /// inside the cascade check by the same margin the
    /// interactive clamps keep (#925/#933). Only weights above
    /// `c` are shaved, so small weights, the smallest member and
    /// the relative order of everything below the cap survive
    /// the heal untouched.
    ///
    /// Pure math over the gap-adjusted span the layout divides
    /// (`weightedSpan`); the caller owns which store it heals,
    /// where the span comes from, and writing the result back.
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
