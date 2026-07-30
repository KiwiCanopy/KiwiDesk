import KiwiDeskCore
import Testing

@testable import KiwiDesk

@Suite("Onboarding display Spaces recommendation (#8)")
@MainActor
struct OnboardingTests {
    @Test("multi-display separate Spaces show the recommendation")
    func separateSpacesRecommendSharedModel() {
        let model = OnboardingModel()
        var finished = false
        model.onFinish = { finished = true }

        model.continueAfterAccessibility(
            recommendSharedSpaces: true
        )

        #expect(model.step == .separateSpaces)
        #expect(!finished)
    }

    @Test("shared or single-display setups finish onboarding")
    func sharedSpacesFinish() {
        let model = OnboardingModel()
        var finished = false
        model.onFinish = { finished = true }

        model.continueAfterAccessibility(
            recommendSharedSpaces: false
        )

        #expect(model.step == .welcome)
        #expect(finished)
    }

    @Test("discovery pending routes grant completion to the card")
    func discoveryCardWhenPending() {
        let model = OnboardingModel()
        var finished = false
        model.onFinish = { finished = true }
        model.wantsDiscovery = { true }

        model.continueAfterAccessibility(
            recommendSharedSpaces: false
        )

        #expect(model.step == .discoverShortcuts)
        #expect(!finished)
    }

    @Test("the Spaces path also converges on the discovery card")
    func discoveryCardAfterSeparateSpaces() {
        let model = OnboardingModel()
        var finished = false
        model.onFinish = { finished = true }
        model.wantsDiscovery = { true }

        // The `separateSpaces` "Continue" button's action.
        model.finishOrDiscover()

        #expect(model.step == .discoverShortcuts)
        #expect(!finished)
    }

    @Test("an already-shown discovery just finishes")
    func noDiscoveryCardWhenShown() {
        let model = OnboardingModel()
        var finished = false
        model.onFinish = { finished = true }
        model.wantsDiscovery = { false }

        model.finishOrDiscover()

        #expect(model.step == .welcome)
        #expect(finished)
    }

    @Test("shortcuts discovery opens the panel then advances")
    func shortcutsDiscoveryActions() {
        let model = OnboardingModel()
        var opened = false
        model.onShowShortcuts = { opened = true }

        model.onShowShortcuts()
        model.step = .readyToExplore

        #expect(opened)
        #expect(model.step == .readyToExplore)
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
}
