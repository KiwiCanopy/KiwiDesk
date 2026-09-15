import Foundation

/// The per-track floor heal's math (#1355): `geometricCap`
/// decides that the floors fit, this re-shares the weights so
/// each track draws its own. The argument is in
/// `docs/design-decisions.md`.
extension TrackLayout {
    /// Weights re-shared so that track `t` draws at least
    /// `floors[t]` and at most `ceilings[t]` of `span` (the
    /// gap-adjusted across-span), on the original weight scale.
    /// A share sinks when it is under `globalFloor`
    /// (`min_window_size`, which the render's cascade check
    /// reads EXACTLY, #925) or more than
    /// `EffectiveSizeBound.matchTolerance` under its own learned
    /// floor (the app's own clamp absorbs that quantum) — so a
    /// legal weight is never rewritten and the #944 shave's
    /// quarter-point never re-sinks a track this pass pinned.
    /// A share OVERFLOWS when it is more than that tolerance
    /// over its members' learned ceiling (#1488): the app draws
    /// no wider, so the surplus was empty screen beside a
    /// fixed-size window. `ceilings` is `.infinity` where no
    /// member has a corroborated one, and empty means none.
    /// A floor-bound track lands `margin` above its floor (the
    /// shave's own `minSizeMargin`, so the two passes agree on
    /// where a share meets its floor) — or AT its ceiling where
    /// that is nearer, the fixed-size case; a ceiling-bound
    /// track lands at the ceiling. Nil when nothing sinks or
    /// overflows, nil when the margined floors do not fit — the
    /// boundary is never written, the count's own overlap
    /// stands — and nil when every ceiling together leaves the
    /// span unfilled, the one honest gap. Between those the
    /// shares are `clamp(λ·weight, low, high)` at the one water
    /// level λ that fills the span: the level rises until a
    /// track's ceiling holds it and sinks until a floor catches
    /// it, which is what pinning the sinkers and re-sharing the
    /// rest computed before ceilings joined.
    public static func flooredWeights(
        weights: [Double],
        span: Double,
        floors: [Double],
        ceilings: [Double] = [],
        globalFloor: Double,
        margin: Double = 0
    ) -> [Double]? {
        guard weights.count > 1, weights.count == floors.count,
            ceilings.isEmpty || ceilings.count == weights.count,
            span > 0
        else { return nil }
        let total = weights.reduce(0, +)
        // A ceiling under its floor is bound noise; the floor
        // wins, since the count already fitted it.
        let highs = weights.indices.map { index -> Double in
            ceilings.isEmpty
                ? .infinity : max(ceilings[index], floors[index])
        }
        let lows = weights.indices.map {
            min(floors[$0] + margin, highs[$0])
        }
        guard total > 0, weights.min() ?? 0 > 0,
            lows.reduce(0, +) <= span,
            highs.reduce(0, +) >= span
        else { return nil }
        let tolerance = Double(EffectiveSizeBound.matchTolerance)
        let shares = weights.map { span * $0 / total }
        let sinks = zip(shares, floors).contains { share, floor in
            share < max(globalFloor, floor - tolerance)
        }
        let overflows = zip(shares, highs).contains { share, high in
            share > high + tolerance
        }
        guard sinks || overflows else { return nil }
        let filled = { (level: Double) -> [Double] in
            weights.indices.map {
                min(highs[$0], max(lows[$0], level * weights[$0]))
            }
        }
        // Σ clamp(λ·w) is continuous and non-decreasing in λ,
        // from Σ lows to Σ highs, so the span's level is bracketed
        // by 0 and a level that lifts every track to its ceiling.
        var lower = 0.0
        var upper = span / (weights.min() ?? 1)
        for _ in 0..<100 {
            let mid = (lower + upper) / 2
            if filled(mid).reduce(0, +) < span {
                lower = mid
            } else {
                upper = mid
            }
        }
        let healed = filled(upper).map { $0 / span * total }
        // Weights are relative; keep every one inside the domain
        // the render floors them at, scaling up rather than
        // letting the floor re-inflate a shrunken share.
        let smallest = healed.min() ?? weightFloor
        let scale = smallest < weightFloor ? weightFloor / smallest : 1
        return healed.map { $0 * scale }
    }
}
