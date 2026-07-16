import Testing

@testable import KiwiDesk

@Suite("Onboarding display Spaces recommendation (#8)")
@MainActor
struct OnboardingTests {
    @Test("separate display Spaces show the recommendation")
    func separateSpacesRecommendSharedModel() {
        let model = OnboardingModel()
        var finished = false
        model.onFinish = { finished = true }

        model.continueAfterAccessibility(
            hasSeparateSpaces: true
        )

        #expect(model.step == .separateSpaces)
        #expect(!finished)
    }

    @Test("shared display Spaces finish onboarding")
    func sharedSpacesFinish() {
        let model = OnboardingModel()
        var finished = false
        model.onFinish = { finished = true }

        model.continueAfterAccessibility(
            hasSeparateSpaces: false
        )

        #expect(model.step == .welcome)
        #expect(finished)
    }
}
