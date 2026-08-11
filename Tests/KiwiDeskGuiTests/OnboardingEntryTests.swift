import CoreGraphics
import Testing

@testable import KiwiDesk

/// Two decisions the tour makes outside any view (#678 Phase 4
/// pass 11): where a replay opens, and whether the coach mark can
/// honestly point at anything.
@Suite("Onboarding entry & coach mark")
@MainActor
struct OnboardingEntryTests {
    // MARK: - Replay entry

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

    // MARK: - Coach mark

    private let onScreen = CGRect(x: 900, y: 1050, width: 24, height: 24)
    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test("it points when there is something to point at")
    func pointsAtAVisibleItem() {
        #expect(
            MenuBarCoachMark.canPoint(
                menuBarAutoHides: false,
                button: onScreen,
                screen: screen
            )
        )
    }

    /// The owner ruled the mark is BUILT and skipped when hidden.
    /// #331 retired a timed menu-bar popover because it fails
    /// under an auto-hidden menu bar; a coach mark inherits that
    /// defect exactly, so the skip is what makes building it
    /// honest rather than a re-run of the retired mistake.
    @Test("an auto-hiding menu bar skips it")
    func autoHideSkips() {
        #expect(
            !MenuBarCoachMark.canPoint(
                menuBarAutoHides: true,
                button: onScreen,
                screen: screen
            )
        )
    }

    @Test("no button means nothing to point at")
    func noButtonSkips() {
        #expect(
            !MenuBarCoachMark.canPoint(
                menuBarAutoHides: false,
                button: nil,
                screen: screen
            )
        )
        #expect(
            !MenuBarCoachMark.canPoint(
                menuBarAutoHides: false,
                button: onScreen,
                screen: nil
            )
        )
    }

    /// A menu-bar manager parking the item off the visible strip
    /// leaves a button whose window is nowhere the user is
    /// looking. Pointing at it is worse than not pointing.
    @Test("an off-screen item skips it")
    func offScreenSkips() {
        #expect(
            !MenuBarCoachMark.canPoint(
                menuBarAutoHides: false,
                button: CGRect(
                    x: 4000,
                    y: 1050,
                    width: 24,
                    height: 24
                ),
                screen: screen
            )
        )
    }
}
