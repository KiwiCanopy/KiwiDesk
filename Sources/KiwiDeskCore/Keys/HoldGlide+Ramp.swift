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

    /// Steps per second once ramp completes (18.0 steps/s; ~2.7 steps
    /// overshoot at 150ms reaction).
    static let glideMaxSteps = 18.0

    /// Seconds to reach `glideMaxSteps`. Owner-ruled on device at 1.8s
    /// (2026-08-29), reaching max speed at ~1080pt travel on default step.
    static let glideRampSeconds: TimeInterval = 1.8

    /// Linear velocity ramp clamped to [glideStartSteps, glideMaxSteps]
    /// (code review 2026-08-29).
    static func glideSteps(elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return glideStartSteps }
        let progress = min(1.0, elapsed / glideRampSeconds)
        let span = glideMaxSteps - glideStartSteps
        return glideStartSteps + span * progress
    }
}
