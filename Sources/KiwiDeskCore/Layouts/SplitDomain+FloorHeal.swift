/// The split stores' floor heal math (#934/#1430) —
/// `TrackLayout.flooredWeights` one store over: a bsp split ratio
/// or the stack master ratio moved so the side drawing under a
/// LEARNED floor draws it. The argument is in
/// `docs/design-decisions.md`.
extension SplitDomain {
    /// One side of a split as the heal reads it: the side's
    /// effective minimum on the axis (`min_window_size` raised
    /// by its members' learned floor) and whether a learned
    /// bound is what raised it.
    public struct SideFloor: Equatable, Sendable {
        public var size: Double
        public var learned: Bool

        public init(size: Double, learned: Bool) {
            self.size = size
            self.learned = learned
        }
    }

    /// What the heal writes, or why it cannot.
    public enum FloorHealVerdict: Equatable, Sendable {
        /// The ratio at which the sinking side draws its floor
        /// plus the margin.
        case healed(Double)
        /// The two floors and their margins exceed the span:
        /// `bindingLow` names the side whose floor blocks the
        /// yield — the low (first, master) side when true, the
        /// high side otherwise. The other side is the one that
        /// sinks.
        case unfit(bindingLow: Bool)
    }

    /// The ratio to store so both sides of a split draw their
    /// floors, nil when the stored one already does. `available`
    /// is the span the LAYOUT divides (the usable extent less
    /// the inner gap, #933's `weightedSpan` rule); `current` the
    /// stored ratio, read as the render draws it — clamped into
    /// the region's range on `globalFloor` (#383) — so a stored
    /// value the render already pins is judged at the pin.
    ///
    /// Only a LEARNED floor sinks a side: the global floor is the
    /// render clamp's, and a stored ratio too extreme for this
    /// display is honoured again on a wider one. A side sinks
    /// when it draws more than `EffectiveSizeBound.matchTolerance`
    /// under its floor (the app's own clamp absorbs that
    /// quantum), so a legal ratio is never rewritten and the
    /// heal is idempotent. The healed value is the nearer edge
    /// of the range plus `margin` (the #925 quarter point, so
    /// the write lands inside the render's exact cascade check);
    /// nil for a region the render piles, and `unfit` when the
    /// margined floors do not fit — the boundary is never
    /// written.
    public static func healedRatio(
        current: Double,
        available: Double,
        globalFloor: Double,
        low: SideFloor,
        high: SideFloor,
        margin: Double = 0
    ) -> FloorHealVerdict? {
        guard available > 0, low.learned || high.learned,
            let drawn = effectiveRatioRange(
                available: available,
                minSize: globalFloor
            )
        else { return nil }
        let ratio = min(max(current, drawn.lowerBound), drawn.upperBound)
        let tolerance = Double(EffectiveSizeBound.matchTolerance)
        let lowDrawn = available * ratio
        let highDrawn = available - lowDrawn
        let lowSinks = low.learned && lowDrawn < low.size - tolerance
        let highSinks =
            high.learned && highDrawn < high.size - tolerance
        guard lowSinks || highSinks else { return nil }
        guard
            let range = effectiveRatioRange(
                available: available,
                minLow: low.size + margin,
                minHigh: high.size + margin
            )
        else { return .unfit(bindingLow: !lowSinks) }
        return .healed(lowSinks ? range.lowerBound : range.upperBound)
    }
}
