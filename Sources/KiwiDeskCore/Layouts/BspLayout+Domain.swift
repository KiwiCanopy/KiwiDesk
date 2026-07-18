import CoreGraphics

/// The BSP layout's shared split-domain rule (#383), split from
/// `BspLayout` for file size (AGENTS.md §2) and — like
/// `StackLayout+Domain` — so the render-time clamp and the
/// interactive resize write cap consume ONE authority and cannot
/// drift (parity rule).
///
/// BSP shares two per-space scalar ratios across every split at a
/// depth, not per-node ratios (a tree the flat array forbids,
/// `BspLayout`). This is not a problem for the render clamp: it
/// runs per region at every recursion level, so a ratio too
/// extreme for a deep sub-region is clamped against *that*
/// region's own span — every depth pins its neighbor to
/// `min_window_size` rather than piling. The write cap can only
/// see the screen span (the shallowest split), so it stops the
/// stored value ratcheting invisibly on the top split; the render
/// clamp is the depth-complete safety net beneath it.
extension BspLayout {
    /// The split-ratio interval that keeps BOTH sides of one
    /// split at least `minSize` long within `available` points,
    /// or nil when two min-size regions cannot coexist at any
    /// ratio — the genuine cascade case the layout answers with
    /// an `OverlapStack`. `minSize` ≤ 0 means no minimum (the
    /// full 0...1), which also fences nonsense stored ratios away
    /// from negative region widths. The two-adjacent-zone
    /// geometry is the same one `StackLayout.effectiveRatioRange`
    /// solves; kept per layout so BSP's authority stays
    /// self-contained rather than cross-coupling the two layouts.
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

    /// Caps an interactive split-ratio write at the effective
    /// range (#383), so a resize can't push a neighbor below
    /// `min_window_size` and trip the overlap cascade. Never
    /// pushes the value back across `base`, so an already
    /// out-of-range stored ratio stays editable in the
    /// re-entering direction — the `StackLayout.cappedRatioWrite`
    /// contract. On a span too narrow to split at all (range nil)
    /// the write is deliberately not capped: there is no visible
    /// bound to stop at, and the value stays editable for a wider
    /// display, bounded by the caller's 0.1…0.9 store clamp.
    ///
    /// Callers pass the raw screen span as `available` — a
    /// superset of the layout's gap-adjusted per-region range, so
    /// the cap can never block reaching the visible bound and the
    /// residual overshoot is bounded by gaps (a few percent),
    /// exactly as the stack write cap does. Callers must pass the
    /// SAME `minSize` the layout resolves (the global today).
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
