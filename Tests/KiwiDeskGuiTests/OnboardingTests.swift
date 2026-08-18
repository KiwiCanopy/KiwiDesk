import KiwiDeskCore
import Testing

@testable import KiwiDesk

@Suite("Onboarding flow")
@MainActor
struct OnboardingTests {
    /// The flow since #888: grant → spaces → keys → done, with no
    /// machine-gated step. (#828's separate-Spaces recommendation
    /// retired with the ruling it recommended around — bindings
    /// key to the main display's Desktop now, so they are
    /// well-defined under the macOS default.) The route still
    /// varies by its DOOR, which is why the progress row derives
    /// its length instead of drawing a fixed counter
    /// (`OnboardingProgressTests`).
    @Test("the grant step hands off to the spaces step")
    func grantLeadsToSpaces() {
        let model = OnboardingModel()
        model.beginPresentation(at: .grant)
        model.continueAfterAccessibility()
        #expect(model.step == .spaces)
        // Nothing has been said yet, so the close seam must not
        // have counted this as reaching the end.
        #expect(!model.reachedEnd)
    }

    /// The keys step is unconditional since #828: it was gated on
    /// the persisted discovery flag, which meant everyone who had
    /// finished the tour once could never see the shortcuts screen
    /// again — including from Home's "Show me around", where they
    /// had just asked for it. #331's ruling is untouched, being
    /// about whether an unfinished tour RESUMES there at launch.
    @Test("the spaces step always leads to the keys step")
    func spacesAlwaysLeadToKeys() {
        let model = OnboardingModel()
        model.beginPresentation(at: .spaces)
        model.continueAfterSpaces()
        #expect(model.step == .keys)
    }

    /// The keys step leads straight to the closing card on every
    /// machine — the step that used to sit between them was the
    /// #888-retired recommendation, and this is the assertion
    /// that reds if a machine-gated step quietly returns without
    /// re-earning the plan seams it would need.
    @Test("the keys step leads to the closing card")
    func keysLeadToDone() {
        let model = OnboardingModel()
        model.beginPresentation(at: .keys)
        model.continueAfterKeys()
        #expect(model.step == .done)
    }

    /// Proves the `didSet` WIRING — that arriving at a step
    /// consults `isClosingBeat` at all — and nothing about which
    /// steps are in that set.
    ///
    /// Read the limit literally, because it is not obvious and it
    /// shipped: both sides of this sweep read the same enum, so
    /// any edit to `isClosingBeat`'s MEMBERSHIP moves the
    /// expectation and the actual together and the sweep stays
    /// green. Removing `.done` from the set passed the entire
    /// suite — 3140 tests — with the tour's final card no longer
    /// counting as the end, i.e. the discovery flag never marked
    /// and Home's banner never seeded on the ordinary finish path
    /// (guard-prover, 2026-08-11 — a third effect, the desktop
    /// coach mark, hung off the same flag until #828 moved
    /// where-the-app-lives inside the closing card).
    /// `everyTerminalRouteReachesTheEnd` below is what holds the
    /// membership; this holds the wiring.
    @Test("arriving at a step consults its closing-beat verdict")
    func reachedEndOnArrival() {
        for step in OnboardingModel.Step.allCases {
            let model = OnboardingModel()
            // Through the one door, since `step` is `private(set)`
            // (#828 review): a presentation's plan is resolved
            // from the step it opens on, so a test that assigned
            // the step directly would be exercising a state no
            // door can produce.
            model.beginPresentation(at: step)
            #expect(
                model.reachedEnd == step.isClosingBeat,
                "\(step) disagreed with its own closing-beat verdict"
            )
        }
        // Vacuity: the sweep is only a claim if both verdicts
        // occur among the cases.
        let beats = OnboardingModel.Step.allCases
            .filter(\.isClosingBeat)
        #expect(!beats.isEmpty)
        #expect(beats.count < OnboardingModel.Step.allCases.count)
    }

    /// The membership half, pinned against the FLOW rather than
    /// against the enum that defines it.
    ///
    /// Every route a real user can take to the end of the tour is
    /// driven through the model's own transitions, and each must
    /// arrive with `reachedEnd` set — because two shipped
    /// effects hang off that flag at `windowWillClose`
    /// (`OnboardingDiscovery.markShown`, `HomeFirstRunState.seed`;
    /// the coach mark was a third until #828). A step dropped
    /// from `isClosingBeat` reds here even though the sweep above
    /// cannot see it.
    @Test("every terminal route arrives having reached the end")
    func everyTerminalRouteReachesTheEnd() {
        // Route 1 — the full tour: grant, spaces, keys, done. The
        // keys step is on every route since #828.
        let direct = OnboardingModel()
        direct.beginPresentation(at: .grant)
        direct.continueAfterAccessibility()
        direct.continueAfterSpaces()
        #expect(direct.step == .keys)
        direct.continueAfterKeys()
        #expect(direct.step == .done)
        #expect(direct.reachedEnd, "the direct route did not count")

        // Route 2 — the user closes ON the keys step rather than
        // continuing. `shouldResume` puts a returning user there
        // directly, so this is a real ending, not an abandonment.
        let closedOnKeys = OnboardingModel()
        closedOnKeys.beginPresentation(at: .grant)
        closedOnKeys.continueAfterAccessibility()
        closedOnKeys.continueAfterSpaces()
        #expect(closedOnKeys.step == .keys)
        #expect(closedOnKeys.reachedEnd)

        // And the steps that are NOT an ending stay uncounted, or
        // the flag would be true from the first screen and mean
        // nothing at all.
        let opening = OnboardingModel()
        opening.beginPresentation(at: .grant)
        #expect(!opening.reachedEnd)
        opening.continueAfterAccessibility()
        #expect(opening.step == .spaces)
        #expect(
            !opening.reachedEnd,
            "the spaces step counted as the end of the tour"
        )
    }

    /// `shouldResume` drops a returning user straight onto the
    /// keys step (#331). Closing THERE must still count, or the
    /// discovery flag is never marked and the tour re-pitches on
    /// every launch — which is what keying the seam on "left a
    /// step" rather than "reached one" would have done.
    @Test("a resumed tour that opens on keys has reached the end")
    func resumedTourCounts() {
        let model = OnboardingModel()
        model.beginPresentation(at: .keys)
        #expect(model.reachedEnd)
    }

    @Test("open-at-login defaults to pre-checked (#342)")
    func loginItemPreChecked() {
        #expect(OnboardingModel().openAtLogin)
    }

    @Test("both exit routes commit the login-item choice (#342)")
    func loginItemCommittedOnExit() {
        for (choice, route) in [(true, "explore"), (false, "finish")] {
            let model = OnboardingModel()
            var applied: Bool?
            var exited = false
            model.openAtLogin = choice
            model.onSetLoginItem = { applied = $0 }

            model.commitLoginItemThen { exited = true }

            // The chosen flag is applied, and applied BEFORE the
            // exit runs (the app closes onboarding on exit).
            #expect(applied == choice, "route \(route)")
            #expect(exited, "route \(route)")
        }
    }
}
