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
    /// That one was fixed: five screens asserted on a machine
    /// that shows three. This is the list the flow will actually
    /// walk — `OnboardingProgressTests` proves it by walking the
    /// model's own transitions rather than by re-listing the
    /// steps. Since #888 retired the tour's one machine-gated
    /// step (the separate-Spaces recommendation — bindings are
    /// well-defined under the macOS default now), the plan
    /// varies only by its DOOR; the derivation stays, because
    /// the door is still a fact nothing later can re-derive, and
    /// because a plan and a flow reading different predicates is
    /// the disagreement that bit this tour twice (#828, and the
    /// `wantsDiscovery` build before it).
    ///
    /// Steps before `entry` are not members. A door that opens
    /// past a screen never shows it, so counting from `.grant` on
    /// Home's "Show me around" would open a trusted replay
    /// reading "2 of 4" on the tour's first screen.
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
