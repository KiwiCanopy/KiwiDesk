import Foundation

/// The per-track floor heal's math (#1355): `geometricCap`
/// decides that the floors fit, this re-shares the weights so
/// each track draws its own. The argument is in
/// `docs/design-decisions.md`.
extension TrackLayout {
    /// Weights re-shared so that track `t` draws at least
    /// `floors[t]` of `span` (the gap-adjusted across-span), on
    /// the original weight scale. A share sinks when it is under
    /// `globalFloor` (`min_window_size`, which the render's
    /// cascade check reads EXACTLY, #925) or more than
    /// `EffectiveSizeBound.matchTolerance` under its own learned
    /// floor (the app's own clamp absorbs that quantum) — so a
    /// legal weight is never rewritten and the #944 shave's
    /// quarter-point never re-sinks a track this pass pinned.
    /// A pinned track lands `margin` above its floor (the
    /// shave's own `minSizeMargin`, so the two passes agree on
    /// where a share meets its floor); nil when nothing sinks,
    /// and nil when the margined floors do not fit — the
    /// boundary is never written, the count's own overlap
    /// stands. Water-filling: a sinking track is pinned and the
    /// rest re-share the remainder by weight, repeated until
    /// nothing sinks; each round pins at least one track, so it
    /// ends within `count` rounds.
    public static func flooredWeights(
        weights: [Double],
        span: Double,
        floors: [Double],
        globalFloor: Double,
        margin: Double = 0
    ) -> [Double]? {
        guard weights.count > 1, weights.count == floors.count,
            span > 0
        else { return nil }
        let total = weights.reduce(0, +)
        let targets = floors.map { $0 + margin }
        guard total > 0, weights.min() ?? 0 > 0,
            targets.reduce(0, +) <= span
        else { return nil }
        let tolerance = Double(EffectiveSizeBound.matchTolerance)
        let sinks: (Double, Double) -> Bool = { share, floor in
            share < max(globalFloor, floor - tolerance)
        }
        var shares = weights.map { span * $0 / total }
        guard zip(shares, floors).contains(where: sinks)
        else { return nil }
        var pinned = [Bool](repeating: false, count: weights.count)
        for _ in weights.indices {
            var sank = false
            for index in weights.indices
            where !pinned[index]
                && sinks(shares[index], floors[index])
            {
                pinned[index] = true
                shares[index] = targets[index]
                sank = true
            }
            guard sank else { break }
            let taken = weights.indices
                .filter { pinned[$0] }
                .reduce(0.0) { $0 + shares[$1] }
            let free = weights.indices
                .filter { !pinned[$0] }
                .reduce(0.0) { $0 + weights[$1] }
            for index in weights.indices where !pinned[index] {
                shares[index] =
                    free > 0
                    ? (span - taken) * weights[index] / free : 0
            }
        }
        let healed = shares.map { $0 / span * total }
        // Weights are relative; keep every one inside the domain
        // the render floors them at, scaling up rather than
        // letting the floor re-inflate a shrunken share.
        let smallest = healed.min() ?? weightFloor
        let scale = smallest < weightFloor ? weightFloor / smallest : 1
        return healed.map { $0 * scale }
    }
}
