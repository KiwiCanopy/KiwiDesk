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
    /// where a share meets its floor — and the render's exact
    /// cascade check, #925, never reads a share AT the global
    /// floor, which a ceiling under it would otherwise pin);
    /// a ceiling-bound track lands at the ceiling, or at that
    /// margined floor where the ceiling sits under it, the
    /// fixed-size case. Ceilings that together cannot fill the
    /// span bind nothing — the render fills the span whatever
    /// the weights say, so the honest gap lands inside the slots
    /// and only the floors are healed. Nil when nothing sinks or
    /// overflows, and nil when the margined floors do not fit —
    /// the boundary is never written, the count's own overlap
    /// stands. Between those the shares are `clamp(λ·weight,
    /// low, high)` at the one water level λ that fills the span:
    /// the level rises until a track's ceiling holds it and
    /// sinks until a floor catches it, which is what pinning the
    /// sinkers and re-sharing the rest computed before ceilings
    /// joined.
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
        let lows = floors.map { $0 + margin }
        // A ceiling under its margined floor is bound noise or
        // the fixed-size case; the floor wins, since the count
        // already fitted it and the render pins nothing under it.
        var highs = weights.indices.map { index -> Double in
            ceilings.isEmpty
                ? .infinity : max(ceilings[index], lows[index])
        }
        if highs.reduce(0, +) < span {
            highs = highs.map { _ in .infinity }
        }
        guard total > 0, weights.min() ?? 0 > 0,
            lows.reduce(0, +) <= span
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
