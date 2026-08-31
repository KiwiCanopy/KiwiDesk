import Foundation

/// Velocity ramp of a held resize (#1082, owner ruling 2026-08-29; replacing
/// #1056). Speed is counted in steps/s (scaled by delta and frame `dt`).
/// Shape pinned in `HoldGlideRampTests`.
extension HoldGlide {
    /// Steps per second at first frame. Lower bound: clears 120 Hz ±2pt floor
    /// (4.8 steps/s for 50pt step). Upper bound: <=1 step overshoot at 150ms
    /// reaction (6.7 steps/s). Designer round 2026-08-29;
    /// docs review 2026-08-29.
    static let glideStartSteps = 6.0

    /// Steps per second once the ramp completes (~2.7 steps of
    /// overshoot at a 150 ms reaction — acceptable only in a
    /// regime the RAMP establishes). Lowering this to buy back
    /// overshoot makes the long haul permanently worse to protect
    /// a case the ramp duration already protects.
    static let glideMaxSteps = 18.0

    /// Seconds to reach `glideMaxSteps`. Owner-ruled on device at
    /// 1.8 s (2026-08-29), OVERRIDING a derivation that said 2.5
    /// (ceiling at ~one screen-span of travel) — recorded because
    /// the derivation is still where a future retune should start,
    /// but feel outranks it: the whole constant exists to be
    /// judged by hand. 1.8 reaches the ceiling at ~1080 pt.
    static let glideRampSeconds: TimeInterval = 1.8

    /// Linear velocity ramp, clamped at both ends. Linear because
    /// displacement is the integral of what the user controls: an
    /// ease-IN makes distance cubic in hold time and unlearnable,
    /// an ease-OUT is a plateau reachable by moving the two
    /// endpoints — which a guard can pin, where a curve is a fifth
    /// free parameter nothing can (code review 2026-08-29).
    static func glideSteps(elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return glideStartSteps }
        let progress = min(1.0, elapsed / glideRampSeconds)
        let span = glideMaxSteps - glideStartSteps
        return glideStartSteps + span * progress
    }
}
