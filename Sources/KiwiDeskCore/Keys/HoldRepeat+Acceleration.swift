import Foundation

/// The acceleration ramp on a held resize (#1056, owner ruling
/// 2026-08-28): start at the system key-repeat rate, speed up
/// over a long hold so coarse adjustment gets fast while the
/// first press stays one precise step. Split from the ladder at
/// the file sweet spot; the constants are feel, retuned at the
/// machine — `HoldRepeatAccelerationTests` pins only the SHAPE
/// (flat start, monotone ramp, hard floor), derived from these
/// values, so a retune reds nothing.
extension HoldRepeat {
    /// Repeat ticks that ride the plain system interval before
    /// acceleration begins. ~1 s at the default macOS rate
    /// (≈12 × 83 ms): long enough that a deliberate short hold
    /// behaves exactly like key repeat anywhere else, short
    /// enough that a hold clearly meant to cover distance gets
    /// its speed-up without a dead stretch.
    static let accelerationStartTick = 12

    /// Per-tick interval multiplier once acceleration starts.
    /// 0.9 reaches the floor below in ~13 further ticks —
    /// about one more second of hold from the system rate to
    /// full speed, a ramp rather than a gear change.
    static let accelerationDecay = 0.9

    /// The speed ceiling: the interval never drops below
    /// `base / maxSpeedup`. 4× keeps the fastest tick slower
    /// than the animation engine's settle churn while still
    /// quartering the presses a long adjustment costs.
    static let maxSpeedup = 4.0

    /// The interval before repeat tick `tick` (1-based, counted
    /// from the first repeat after the initial delay): the base
    /// system interval through `accelerationStartTick`, then a
    /// geometric ease-down floored at `base / maxSpeedup`.
    /// Pure so the shape is testable without timers.
    static func acceleratedInterval(
        base: TimeInterval,
        tick: Int
    ) -> TimeInterval {
        let past = tick - accelerationStartTick
        guard past > 0 else { return base }
        let eased = base * pow(accelerationDecay, Double(past))
        return max(eased, base / maxSpeedup)
    }
}
