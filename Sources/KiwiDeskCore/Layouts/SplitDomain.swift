/// Pure interval geometry shared by every two-zone split: the
/// stack's master/stack split (#44) and each BSP split (#383).
/// Given a 1D span and a per-window minimum it answers two
/// questions — the ratio interval that keeps both halves at least
/// `minSize` long, and how far an interactive write may push the
/// ratio before that bound. The math carries no layout identity
/// (it is "split one span in two, keep both ≥ min"), so it lives
/// in one neutral authority rather than duplicated per layout —
/// the single source the stack and BSP clamps both call, so they
/// cannot drift (AGENTS.md §5 parity rule).
public enum SplitDomain {
    /// The ratio interval that keeps BOTH sides of a split at
    /// least `minSize` long within `available` points, or nil
    /// when two min-size halves cannot coexist at any ratio — the
    /// cascade case a layout answers with an `OverlapStack`.
    /// `minSize` ≤ 0 (or NaN) means no minimum: the full 0...1,
    /// which also fences nonsense stored ratios away from
    /// negative widths.
    public static func effectiveRatioRange(
        available: Double,
        minSize: Double
    ) -> ClosedRange<Double>? {
        // A degenerate region (gaps wider than the usable area)
        // cascades regardless of the minimum.
        guard available > 0 else { return nil }
        guard minSize > 0 else { return 0...1 }
        guard available >= minSize * 2 else { return nil }
        let fraction = minSize / available
        return fraction...(1 - fraction)
    }

    /// Caps an interactive ratio write at the effective range, so
    /// a resize can't push a neighbor below `minSize` and trip the
    /// cascade. Never pushes the value back across `base`, so an
    /// already out-of-range stored ratio stays editable in the
    /// direction that re-enters the range (a further push the same
    /// way freezes at `base` — no invisible ratchet). On a span
    /// too narrow to split at all (range nil) the write is
    /// deliberately not capped: there is no visible bound to stop
    /// at, and the value stays editable for a wider display,
    /// bounded only by the caller's store clamp. The config verbs
    /// (`stack.set_master_ratio`, `bsp.set_ratio_*`) deliberately
    /// bypass this: a stored value too extreme for this display is
    /// honored again on a wider one.
    ///
    /// Callers pass the raw screen span as `available` — a
    /// superset of the layout's gap-adjusted per-region range, so
    /// the cap can never block reaching the visible bound. The
    /// residual overshoot (stored value ratcheting slightly past
    /// the true cliff) is a thin sliver for a window in the
    /// shallowest split, but wider for one in a deep sub-region,
    /// where this span is a multiple of the region's own: the
    /// per-region render clamp is the depth-complete safety net
    /// beneath this cap. Callers must pass the SAME `minSize` the
    /// layout resolves (the global today).
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
}
