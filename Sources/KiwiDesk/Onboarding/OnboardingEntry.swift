import Foundation
import KiwiDeskCore

/// Pure routing decisions for onboarding tour entry points.
@MainActor
enum OnboardingEntry {
    /// Returns initial step for voluntary replay: .spaces once
    /// tiling runs, .grant while the permission or the Start
    /// Tiling press is still owed (#678, #2050).
    static func replayStep(
        isTrusted: Bool,
        hasStartedTiling: Bool
    ) -> OnboardingModel.Step {
        isTrusted && hasStartedTiling ? .spaces : .grant
    }

    /// Returns the sequence of steps from `entry` to the end of
    /// the tour (#678, #828, #888, OnboardingProgressTests).
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
