import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's grant screen has three states, not two (#801/#802).
///
/// Before the boot was chunked, the post-grant `Continue` hung
/// until the whole scan finished, so "your open windows have been
/// arranged" was true by the time anyone could read it. Now the
/// screen is reachable mid-scan — the button answers immediately —
/// and that copy would be the app's first sentence about itself
/// being a claim it has not finished making.
///
/// Read off the view's own properties rather than a rendered
/// frame: the branch lives inside a `body`, which every other
/// guard in this tree passes straight over (gui.md's surfacing
/// -branch lesson). `@MainActor` because they are `View`
/// properties, and `.serialized` because the strings are matched
/// in English through the process-wide `LocalizationManager`.
@Suite("Onboarding grant readiness copy (#802)", .serialized)
@MainActor
struct OnboardingGrantPhaseTests {
    private func view(
        trusted: Bool,
        phase: BootPhase
    ) -> OnboardingView {
        LocalizationManager.shared.select("en")
        let model = OnboardingModel()
        model.isTrusted = trusted
        model.bootPhase = phase
        return OnboardingView(model: model)
    }

    @Test("ungranted copy is unchanged by the boot phase")
    func ungrantedIgnoresThePhase() {
        let waiting = view(
            trusted: false,
            phase: .scanning(scanned: 3, total: 9)
        )
        #expect(waiting.grantTitle == "KiwiDesk needs Accessibility")
        // The permission is the only subject until it is granted:
        // a boot count on this screen would narrate a scan that
        // has not started.
        #expect(waiting.grantBody.hasPrefix("macOS only lets an app"))
    }

    @Test("the arranging state does not claim a finished job")
    func arrangingWithholdsTheClaim() {
        let arranging = view(
            trusted: true,
            phase: .scanning(scanned: 12, total: 109)
        )

        #expect(arranging.grantTitle == "Arranging your windows")
        #expect(
            arranging.grantBody.hasPrefix("KiwiDesk is going through")
        )
        // The one sentence that must NOT appear yet — it tells the
        // user to look behind a window at an arrangement that is
        // still being computed.
        #expect(!arranging.grantBody.contains("have been arranged"))
        // The exception for the tour's own window is stated in
        // both states, from ONE key: a second copy would be
        // translated twice and could then be rewritten under the
        // reader's eyes at `.ready`.
        #expect(arranging.grantBody.contains("left alone"))
        #expect(arranging.isArranging)
    }

    @Test("the count rides the footer hint, with the number last")
    func countRidesTheHint() {
        let arranging = view(
            trusted: true,
            phase: .scanning(scanned: 12, total: 109)
        )

        // The hint slot is the one built for a fact the user does
        // not act on, and Continue is live throughout
        // (ui-designer, 2026-08-12). Under the hero the tally
        // shared an object with the app's one success mark.
        #expect(
            arranging.grantHintForPhase
                == "Still going through your open apps: 12 of 109"
        )
        // Not the menu's sentence: this reader is one minute into
        // owning the app. The NUMBER is what both surfaces share.
        #expect(
            arranging.grantHintForPhase?.contains("12 of 109") == true
        )
    }

    @Test("neither trusted end-state carries a count")
    func endStatesCarryNoCount() {
        #expect(view(trusted: true, phase: .ready).grantHintForPhase == nil)
        #expect(!view(trusted: true, phase: .ready).isArranging)
        // Ungranted keeps the SIP/keystrokes promise in the slot —
        // the sentence that earns the button beside it.
        let waiting = view(trusted: false, phase: .idle)
        #expect(waiting.grantHintForPhase?.contains("keystrokes") == true)
    }

    @Test("the arranged claim lands when boot is ready")
    func readyMakesTheClaim() {
        let done = view(trusted: true, phase: .ready)

        #expect(done.grantTitle == "Your windows are arranged")
        #expect(done.grantBody.contains("have been arranged"))
    }

    @Test("only ready claims the job is done")
    func onlyReadyClaimsTheJob() {
        // The claim is gated on `.ready`, not on "not scanning":
        // `.idle` is a paused or not-yet-started core, and the gap
        // before the first publication is reachable the moment
        // anything shortens `loadConfig`'s synchronous block —
        // which is the direction #801 travels (ui-designer,
        // 2026-08-12). A screen that asserts a finished
        // arrangement in either state is asserting something no
        // phase said.
        let idle = view(trusted: true, phase: .idle)
        #expect(idle.grantTitle == "Arranging your windows")
        #expect(!idle.grantBody.contains("have been arranged"))
        // …and it carries no count, there being no scan to report.
        #expect(idle.grantHintForPhase == nil)
    }
}
