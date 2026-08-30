import Foundation
import KiwiDeskCore

/// Pure routing decisions for onboarding tour entry points.
@MainActor
enum OnboardingEntry {
    /// Returns initial step for voluntary replay (.spaces if trusted,
    /// .grant otherwise).
    static func replayStep(
        isTrusted: Bool
    ) -> OnboardingModel.Step {
        isTrusted ? .spaces : .grant
    }

    /// Returns the sequence of steps from `entry` to the end of
    /// the tour (#828, #888).
    static func plannedSteps(
        from entry: OnboardingModel.Step
    ) -> [OnboardingModel.Step] {
        let all = OnboardingModel.Step.allCases
        guard let start = all.firstIndex(of: entry) else {
            return all
        }
        return Array(all[start...])
    }
}
