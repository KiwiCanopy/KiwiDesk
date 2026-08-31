/// Ratio calculations and clamps for two-zone layouts (#44, #383,
/// AGENTS.md §5).
public enum SplitDomain {
    /// Valid ratio interval given symmetric minimum size (`OverlapStack`).
    public static func effectiveRatioRange(
        available: Double,
        minSize: Double
    ) -> ClosedRange<Double>? {
        effectiveRatioRange(
            available: available,
            minLow: minSize,
            minHigh: minSize
        )
    }

    /// Valid ratio interval supporting asymmetric minimums (#677, #933).
    public static func effectiveRatioRange(
        available: Double,
        minLow: Double,
        minHigh: Double
    ) -> ClosedRange<Double>? {
        guard available > 0 else { return nil }
        let low = max(minLow, 0)
        let high = max(minHigh, 0)
        guard low > 0 || high > 0 else { return 0...1 }
        guard available >= low + high else { return nil }
        return (low / available)...(1 - high / available)
    }

    /// Clamps interactive ratio write to prevent cascade (#933).
    /// Never pushes the value back across `base` — no invisible
    /// ratchet — and a nil-range span is deliberately uncapped.
    /// The config verbs (`stack.set_master_ratio`,
    /// `bsp.set_ratio_*`) bypass this: a stored value too extreme
    /// for this display is honored again on a wider one. Callers
    /// pass the raw screen span; the per-region render clamp is
    /// the depth-complete net beneath this cap.
    public static func cappedRatioWrite(
        _ proposed: Double,
        base: Double,
        available: Double,
        minSize: Double
    ) -> Double {
        cappedRatioWrite(
            proposed,
            base: base,
            available: available,
            minLow: minSize,
            minHigh: minSize
        ).value
    }

    /// Clamped ratio result and boundary clamp status (#933).
    public struct RatioWriteOutcome: Equatable, Sendable {
        public let value: Double
        public let clamped: Bool
    }

    /// Two-sided interactive ratio writer respecting minimum size bounds
    /// (#933).
    public static func cappedRatioWrite(
        _ proposed: Double,
        base: Double,
        available: Double,
        minLow: Double,
        minHigh: Double
    ) -> RatioWriteOutcome {
        guard
            let range = effectiveRatioRange(
                available: available,
                minLow: minLow,
                minHigh: minHigh
            )
        else {
            return RatioWriteOutcome(
                value: proposed,
                clamped: false
            )
        }
        if proposed > base {
            let value = min(
                proposed,
                max(range.upperBound, base)
            )
            return RatioWriteOutcome(
                value: value,
                clamped: value < proposed
            )
        }
        if proposed < base {
            let value = max(
                proposed,
                min(range.lowerBound, base)
            )
            return RatioWriteOutcome(
                value: value,
                clamped: value > proposed
            )
        }
        return RatioWriteOutcome(value: proposed, clamped: false)
    }
}
