import Testing

@testable import KiwiDesk

/// Where a replay of the tour opens (#678 Phase 4 pass 11).
///
/// The coach-mark half of this suite went with the mark itself
/// (#828): the desktop callout that used to float under the real
/// menu-bar item after the tour closed is now a row INSIDE the
/// closing card, so the three conditions it skipped itself under
/// — an auto-hidden menu bar, no status button, an item parked
/// off-screen by a menu-bar manager — no longer exist. A picture
/// drawn in the app's own window has nothing to miss.
@Suite("Onboarding entry")
@MainActor
struct OnboardingEntryTests {
    /// Deleting `.welcome` made the grant step the tour's first
    /// screen, and Home's "Show me around" is the one entry point
    /// where nothing is broken. Without this, the person who ASKED
    /// for the tour opens on a permission screen reading
    /// "Permission granted" — the exact repair the pass owed.
    @Test("a trusted replay skips the grant step")
    func trustedReplaySkipsGrant() {
        #expect(
            OnboardingEntry.replayStep(isTrusted: true) == .spaces
        )
    }

    @Test("an untrusted replay still opens on the grant step")
    func untrustedReplayStartsAtGrant() {
        #expect(
            OnboardingEntry.replayStep(isTrusted: false) == .grant
        )
        // And the step it lands on is one the tour does not count
        // as having said anything — closing there must not mark
        // the discovery flag.
        #expect(
            !OnboardingEntry.replayStep(isTrusted: false)
                .isClosingBeat
        )
    }
}
