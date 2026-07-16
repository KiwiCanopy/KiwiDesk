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
