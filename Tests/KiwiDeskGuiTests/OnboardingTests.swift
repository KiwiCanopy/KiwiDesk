import KiwiDeskCore
import Testing

@testable import KiwiDesk

@Suite("Onboarding display Spaces recommendation (#8)")
@MainActor
struct OnboardingTests {
    /// The flow after #678 Phase 4 pass 11: grant → spaces →
    /// keys (gated) → Displays (gated) → done. The two gated
    /// steps are why no screen draws a step counter.
    @Test("the grant step hands off to the spaces step")
    func grantLeadsToSpaces() {
        let model = OnboardingModel()
        model.continueAfterAccessibility()
        #expect(model.step == .spaces)
        // Nothing has been said yet, so the close seam must not
        // have counted this as reaching the end.
        #expect(!model.reachedEnd)
    }

    @Test("a pending discovery routes the spaces step to keys")
    func spacesLeadToKeysWhenPending() {
        let model = OnboardingModel()
        model.wantsDiscovery = { true }
        model.continueAfterSpaces()
        #expect(model.step == .keys)
    }

    @Test("an already-shown discovery skips the keys step")
    func spacesSkipKeysWhenShown() {
        let model = OnboardingModel()
        model.wantsDiscovery = { false }
        model.displayCount = { 1 }
        model.continueAfterSpaces()
        #expect(model.step == .done)
    }

    @Test("multi-display separate Spaces show the recommendation")
    func separateSpacesRecommendSharedModel() {
        let model = OnboardingModel()
        // The recommendation is now the LAST substantive step,
        // reached from the keys step rather than from the grant.
        model.displayCount = { 2 }
        model.continueAfterKeys()
        // Only meaningful where the live pref has separate Spaces
        // on; the predicate's display half is what this drives.
        let recommends =
            DisplaySpacesSetting
            .recommendsSharedSpaces(displayCount: 2)
        #expect(
            model.step == (recommends ? .separateSpaces : .done)
        )
    }

    @Test("a single display goes straight to the closing card")
    func singleDisplaySkipsTheRecommendation() {
        let model = OnboardingModel()
        model.displayCount = { 1 }
        model.continueAfterKeys()
        #expect(model.step == .done)
    }

    @Test("the recommendation's Continue reaches the closing card")
    func separateSpacesLeadsToDone() {
        let model = OnboardingModel()
        model.continueAfterSeparateSpaces()
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
    /// counting as the end, i.e. the discovery flag never marked,
    /// Home's banner never seeded and the coach mark never shown
    /// on the ordinary finish path (guard-prover, 2026-08-11).
    /// `everyTerminalRouteReachesTheEnd` below is what holds the
    /// membership; this holds the wiring.
    @Test("arriving at a step consults its closing-beat verdict")
    func reachedEndOnArrival() {
        for step in OnboardingModel.Step.allCases {
            let model = OnboardingModel()
            model.step = step
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
    /// arrive with `reachedEnd` set — because three shipped
    /// effects hang off that flag at `windowWillClose`
    /// (`OnboardingDiscovery.markShown`, `HomeFirstRunState.seed`,
    /// the coach mark). A step dropped from `isClosingBeat` reds
    /// here even though the sweep above cannot see it.
    @Test("every terminal route arrives having reached the end")
    func everyTerminalRouteReachesTheEnd() {
        // Route 1 — discovery already shown, one display: the
        // spaces step goes straight to the closing card.
        let direct = OnboardingModel()
        direct.wantsDiscovery = { false }
        direct.displayCount = { 1 }
        direct.continueAfterAccessibility()
        direct.continueAfterSpaces()
        #expect(direct.step == .done)
        #expect(direct.reachedEnd, "the direct route did not count")

        // Route 2 — through the keys step.
        let viaKeys = OnboardingModel()
        viaKeys.wantsDiscovery = { true }
        viaKeys.displayCount = { 1 }
        viaKeys.continueAfterAccessibility()
        viaKeys.continueAfterSpaces()
        #expect(viaKeys.step == .keys)
        viaKeys.continueAfterKeys()
        #expect(viaKeys.step == .done)
        #expect(viaKeys.reachedEnd, "the keys route did not count")

        // Route 3 — through the Displays recommendation, which is
        // the last substantive step when it appears at all.
        let viaSpaces = OnboardingModel()
        viaSpaces.continueAfterSeparateSpaces()
        #expect(viaSpaces.step == .done)
        #expect(
            viaSpaces.reachedEnd,
            "the Displays route did not count"
        )

        // Route 4 — the user closes ON the keys step rather than
        // continuing. `shouldResume` puts a returning user there
        // directly, so this is a real ending, not an abandonment.
        let closedOnKeys = OnboardingModel()
        closedOnKeys.wantsDiscovery = { true }
        closedOnKeys.continueAfterAccessibility()
        closedOnKeys.continueAfterSpaces()
        #expect(closedOnKeys.step == .keys)
        #expect(closedOnKeys.reachedEnd)

        // And the steps that are NOT an ending stay uncounted, or
        // the flag would be true from the first screen and mean
        // nothing at all.
        let opening = OnboardingModel()
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
        model.step = .keys
        #expect(model.reachedEnd)
    }

    @Test("shortcuts panel opens from the keys step")
    func shortcutsPanelOpens() {
        let model = OnboardingModel()
        var opened = false
        model.onShowShortcuts = { opened = true }
        model.onShowShortcuts()
        #expect(opened)
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

    @Test("single display never triggers the recommendation")
    func singleDisplayNeverRecommends() {
        // A single display can't have ambiguous Desktop→profile
        // bindings, so the gate must suppress the step even with
        // separate Spaces on. Predicate lives in Core; assert the
        // display-count half here (the hasSeparateSpaces half
        // reads a live system pref and isn't unit-testable).
        #expect(
            !DisplaySpacesSetting.recommendsSharedSpaces(
                displayCount: 1
            )
        )
    }

    /// The overload that takes an ALREADY-READ preference (#678
    /// turn 13a) — the Settings dashboard snapshots the
    /// `CFPreferences` value but must evaluate the display half
    /// live, and routing through Core is what keeps #8's
    /// one-predicate promise from quietly becoming two copies.
    ///
    /// Unlike the live-read overload above, both halves ARE
    /// unit-testable here, so all four combinations are pinned:
    /// inverting either arm is otherwise silent.
    @Test("the pre-read overload agrees on every combination")
    func preReadOverloadTruthTable() {
        #expect(
            DisplaySpacesSetting.recommendsSharedSpaces(
                separateSpaces: true,
                displayCount: 2
            )
        )
        #expect(
            !DisplaySpacesSetting.recommendsSharedSpaces(
                separateSpaces: true,
                displayCount: 1
            )
        )
        #expect(
            !DisplaySpacesSetting.recommendsSharedSpaces(
                separateSpaces: false,
                displayCount: 2
            )
        )
        #expect(
            !DisplaySpacesSetting.recommendsSharedSpaces(
                separateSpaces: false,
                displayCount: 1
            )
        )
    }
}
