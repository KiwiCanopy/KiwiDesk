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
        #expect(arranging.grantBody.hasPrefix("Permission is on."))
        // The one sentence that must NOT appear yet — it tells the
        // user to look behind a window at an arrangement that is
        // still being computed.
        #expect(!arranging.grantBody.contains("have been arranged"))
        // The exception for the tour's own window is stated in
        // both states: it is the answer to "why is this window
        // special", and it is as true mid-scan as after.
        #expect(arranging.grantBody.contains("left alone"))
    }

    @Test("the arranged claim lands when boot is ready")
    func readyMakesTheClaim() {
        let done = view(trusted: true, phase: .ready)

        #expect(done.grantTitle == "Your windows are arranged")
        #expect(done.grantBody.contains("have been arranged"))
    }

    @Test("an idle phase reads as arranged, never as arranging")
    func idleIsNotArranging() {
        // `.idle` is a paused core (no permission, or a revoke),
        // and this screen is only reached with the grant in hand —
        // so the honest reading of "not scanning" here is the
        // finished one. The predicate is `isStarting`, never
        // "is not ready", which would put the tour into a
        // permanent arranging state on any pause.
        let idle = view(trusted: true, phase: .idle)
        #expect(idle.grantTitle == "Your windows are arranged")
    }
}
