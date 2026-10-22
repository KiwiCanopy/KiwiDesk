import Foundation
import Testing

/// The bars step's doors and the looks step's hold live in wiring
/// the model tests stub out (#2515). Each needle is keyed on its
/// use site.
@Suite("Onboarding bars wiring (#2515)")
struct OnboardingBarsWiringTests {
    private func source(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/" + path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
    }

    @Test("a pick and a revert reach Core's visibility doors")
    func doorsAreWired() throws {
        let wiring = try source("AppDelegate+OnboardingBars.swift")
        #expect(
            wiring.contains("self?.core.setBarVisibility(visibility)")
        )
        #expect(
            wiring.contains("self?.core.restoreBarVisibility(baseline)")
        )
        #expect(
            wiring.contains(
                "bars.settingsDraftPending = { [weak self] in\n"
                    + "            self?.dashboardIfCreated?"
                    + ".hasUnsavedDraft"
            )
        )
        #expect(wiring.contains("self?.core.holdBarsRevealed(held)"))
        #expect(
            wiring.contains(
                "OnboardingKeys.revealFamilies(layer: layer)"
            )
        )
    }

    @Test("the tour wires the step and releases the hold on close")
    func tourWiresAndReleases() throws {
        let tour = try source("AppDelegate+Onboarding.swift")
        #expect(tour.contains("wireOnboardingBars()"))
        #expect(
            tour.contains(
                "onboardingWindow = nil\n"
                    + "        onboardingModel.endPresentation()"
            )
        )
    }

    @Test("the step is drawn")
    func stepIsDrawn() throws {
        let view = try source("Onboarding/OnboardingView.swift")
        #expect(
            view.contains(
                "case .bars:\n"
                    + "                OnboardingBarsStep(model: model)"
            )
        )
    }
}
