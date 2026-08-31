import CoreGraphics
import Foundation

/// Settle watchdog policy and non-finite rescue for `FrameAnimation`
/// (#611, #599, `.claude/rules/input-and-animation.md`).
extension FrameAnimation {
    /// Settle watchdog bounds (`slowestHealthySettleIsPinned`,
    /// #611, #511). Bound formula:
    /// `max(ageFloor, min(ageResponseMultiple * response, ageCeiling))`
    /// — both terms carry margin: the multiple covers a slow spring
    /// settling honestly, the ceiling caps a pathological response
    /// value so no animation can earn an effectively-infinite age
    /// bound.
    private static let ageResponseMultiple = 12.0
    private static let ageFloor: TimeInterval = 5
    private static let ageCeiling: TimeInterval = 60

    /// Whether animation has exceeded watchdog threshold and must
    /// be force-settled — an animation that never settles kills the
    /// settle signal for the whole session (#599). Single caller:
    /// `tick`, which owns acting on it (`onAllAnimationsEnded`,
    /// #611).
    var isOverdue: Bool {
        let scaled = min(
            Self.ageResponseMultiple * spring.response,
            Self.ageCeiling
        )
        return age > max(Self.ageFloor, scaled)
    }

    /// Whether non-finite recovery net fired, clearing notice flag (#611).
    mutating func takeNonFiniteNotice() -> Bool {
        defer { pendingRescueNotice = false }
        return pendingRescueNotice
    }
}
