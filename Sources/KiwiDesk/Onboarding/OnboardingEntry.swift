import Foundation

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
}
