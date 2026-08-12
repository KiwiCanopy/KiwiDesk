import Foundation
import KiwiDeskCore

/// Which step an entry point into the tour opens on.
///
/// Pure, so the decision is assertable without building an
/// `AppDelegate` — which would reach the live Carbon chords and
/// the real config directory (`.claude/rules/tests.md`).
@MainActor
enum OnboardingEntry {
    /// Where Home's "Show me around" opens (turn 14c), the tour's
    /// one VOLUNTARY entry point.
    ///
    /// The grant step is the tour's first screen since `.welcome`
    /// was deleted (#678 Phase 4 pass 11), and it is the wrong
    /// place to put someone who asked to see the tour and has
    /// already granted the permission: they would land on a
    /// screen whose whole subject is a thing that is already
    /// done, reading "Permission granted". So a trusted replay
    /// starts at the first screen that still has something to
    /// say.
    ///
    /// The involuntary entry points do NOT come through here —
    /// the quick menu's "fix Accessibility" wants the grant step
    /// precisely because the permission is what is broken.
    static func replayStep(
        isTrusted: Bool
    ) -> OnboardingModel.Step {
        isTrusted ? .spaces : .grant
    }

    /// The steps a presentation opening at `entry` will show, in
    /// order — the progress row's length and its content (#828).
    ///
    /// **This is not the counter #678 Phase 4 pass 11 banned.**
    /// That one was fixed: five screens asserted on a machine that
    /// shows three. This is the list the flow will actually walk,
    /// which is why it takes the same two answers the transitions
    /// take — `wantsDiscovery` gates `.keys`
    /// (`OnboardingModel.continueAfterSpaces`) and the display
    /// count gates `.separateSpaces`
    /// (`OnboardingModel.continueAfterKeys`) — and why
    /// `OnboardingProgressTests` proves it by walking the model's
    /// own transitions rather than by re-listing the steps.
    ///
    /// The display count goes through Core's one predicate rather
    /// than a copy of it: `recommendsSharedSpaces` has a second
    /// half (the live "Displays have separate Spaces" preference)
    /// and a row that read only the count would promise a screen
    /// on every multi-display Mac.
    ///
    /// Steps before `entry` are not members. A door that opens
    /// past a screen never shows it, so counting from `.grant` on
    /// Home's "Show me around" would open a trusted replay
    /// reading "2 of 4" on the tour's first screen.
    static func plannedSteps(
        from entry: OnboardingModel.Step,
        wantsDiscovery: Bool,
        displayCount: Int
    ) -> [OnboardingModel.Step] {
        let all = OnboardingModel.Step.allCases
        guard let start = all.firstIndex(of: entry) else {
            return all
        }
        return all[start...].filter { step in
            switch step {
            case .grant, .spaces, .done: true
            case .keys: wantsDiscovery
            case .separateSpaces:
                DisplaySpacesSetting.recommendsSharedSpaces(
                    displayCount: displayCount
                )
            }
        }
    }
}
