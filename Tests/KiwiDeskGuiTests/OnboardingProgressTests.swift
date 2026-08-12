import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's progress row is DERIVED from the steps this machine
/// will show (#828), which is a different claim from the fixed
/// counter #678 Phase 4 pass 11 banned: "step 3 of 5" is a lie on
/// a machine that shows three steps, and this suite is what keeps
/// the row from becoming one again.
///
/// Every test here pins `displayCount` to 1 unless it is testing
/// the multi-display arm, because `recommendsSharedSpaces` reads a
/// live system preference on its other half — at one display the
/// predicate is false whatever that preference says
/// (`OnboardingTests.singleDisplayNeverRecommends`).
@Suite("Onboarding progress row derivation (#828)")
@MainActor
struct OnboardingProgressTests {

    /// The claim the row makes, stated as a test: what it counts
    /// is what the user is then walked through.
    ///
    /// Driven through the model's OWN transitions rather than
    /// against a hand-written list — a plan derived from one copy
    /// of the gates and a flow driven by another would agree in a
    /// test that wrote both down.
    @Test("the plan is the route the tour actually walks")
    func planMatchesTheWalkedRoute() {
        for wantsKeys in [true, false] {
            let model = OnboardingModel()
            model.wantsDiscovery = { wantsKeys }
            model.displayCount = { 1 }
            model.beginPresentation(at: .grant)

            let planned = model.plannedSteps
            var walked: [OnboardingModel.Step] = [model.step]
            while model.step != .done {
                switch model.step {
                case .grant: model.continueAfterAccessibility()
                case .spaces: model.continueAfterSpaces()
                case .keys: model.continueAfterKeys()
                case .separateSpaces:
                    model.continueAfterSeparateSpaces()
                case .done: break
                }
                walked.append(model.step)
            }

            #expect(
                planned == walked,
                Comment(
                    rawValue: "keys \(wantsKeys): planned "
                        + "\(planned) walked \(walked)"
                )
            )
        }
    }

    /// Vacuity, and the whole point: two machines get two plans.
    /// A row that returned `Step.allCases` — the fixed counter,
    /// wearing a derivation's name — passes every test above.
    @Test("the plan's length varies with the machine")
    func planLengthIsNotConstant() {
        let withKeys = OnboardingModel()
        withKeys.wantsDiscovery = { true }
        withKeys.displayCount = { 1 }
        withKeys.beginPresentation(at: .grant)

        let withoutKeys = OnboardingModel()
        withoutKeys.wantsDiscovery = { false }
        withoutKeys.displayCount = { 1 }
        withoutKeys.beginPresentation(at: .grant)

        #expect(
            withKeys.plannedSteps.count
                == withoutKeys.plannedSteps.count + 1
        )
        #expect(
            withoutKeys.plannedSteps.count
                < OnboardingModel.Step.allCases.count
        )
    }

    /// A door that opens past a screen never counts it (#331's
    /// resumed tour, and Home's "Show me around" on a trusted
    /// Mac): a row counting from `.grant` there would open
    /// reading "2 of 4" on the tour's own first screen.
    @Test("steps before the entry door are not counted")
    func entryDoorTrimsThePlan() {
        let model = OnboardingModel()
        model.isTrusted = true
        model.wantsDiscovery = { true }
        model.displayCount = { 1 }
        model.beginPresentation(at: .spaces)

        #expect(!model.plannedSteps.contains(.grant))
        #expect(model.plannedSteps.first == .spaces)
        #expect(model.progressIndex == 0)
    }

    /// The permission LANDS mid-tour: `isTrusted` flips while the
    /// grant screen is still on display, and again while the user
    /// reads the screens after it. A plan re-deriving `.grant`
    /// from that flag would drop a step the user had just
    /// completed, re-number everything after it, and count the
    /// tour backwards at the moment it says the grant worked.
    @Test("a granted permission does not shorten the plan")
    func grantStaysCountedOnceEntered() {
        let model = OnboardingModel()
        model.wantsDiscovery = { true }
        model.displayCount = { 1 }
        model.beginPresentation(at: .grant)
        let before = model.plannedSteps

        model.isTrusted = true
        #expect(model.plannedSteps == before)
        #expect(model.progressIndex == 0)

        model.continueAfterAccessibility()
        #expect(model.plannedSteps == before)
        #expect(model.progressIndex == 1)
    }

    /// The snapshot's promise, and its stated cost.
    ///
    /// The plan is resolved once, at `beginPresentation`, so a
    /// display unplugged mid-tour does not re-number the row
    /// under the reader — the row keeps its length and the
    /// marker simply advances past the screen the flow now
    /// skips. A recomputing plan would shorten while the user
    /// watched, which is the counter pass 11 banned in motion
    /// rather than at rest.
    @Test("a gate falsified mid-tour does not re-plan the row")
    func theRowDoesNotRePlanUnderTheReader() {
        let model = OnboardingModel()
        var displays = 2
        model.wantsDiscovery = { false }
        model.displayCount = { displays }
        model.beginPresentation(at: .spaces)
        let planned = model.plannedSteps

        // One display makes the predicate false whatever the
        // live pref says (`recommendsSharedSpaces`), so the fall
        // is guaranteed rather than dependent on the machine.
        displays = 1
        #expect(model.plannedSteps == planned)

        // …and the flow, which does read it live, walks past the
        // step. The row still ends on its last pip.
        model.continueAfterSpaces()
        #expect(model.step == .done)
        #expect(
            model.progressIndex == model.plannedSteps.count - 1
        )
    }

    /// The multi-display arm, expected from the same predicate the
    /// transition uses — the live half of it is a system
    /// preference no unit test may set.
    @Test("the Displays recommendation counts only when it fires")
    func displaysRecommendationCountsWhenItFires() {
        let model = OnboardingModel()
        model.wantsDiscovery = { false }
        model.displayCount = { 2 }
        model.beginPresentation(at: .grant)
        let recommends =
            DisplaySpacesSetting
            .recommendsSharedSpaces(displayCount: 2)

        #expect(
            model.plannedSteps.contains(.separateSpaces)
                == recommends
        )
    }

    /// Progress reads as progress: each Continue moves the index
    /// forward by exactly one, and the last step is the last
    /// index. A plan that grew or reordered mid-tour would show
    /// the pill jumping or standing still.
    @Test("the index advances one step at a time to the end")
    func indexAdvancesMonotonically() {
        let model = OnboardingModel()
        model.wantsDiscovery = { true }
        model.displayCount = { 1 }
        model.beginPresentation(at: .grant)

        var seen: [Int?] = [model.progressIndex]
        while model.step != .done {
            switch model.step {
            case .grant: model.continueAfterAccessibility()
            case .spaces: model.continueAfterSpaces()
            case .keys: model.continueAfterKeys()
            case .separateSpaces:
                model.continueAfterSeparateSpaces()
            case .done: break
            }
            seen.append(model.progressIndex)
        }

        #expect(seen == (0..<seen.count).map { Int?($0) })
        #expect(
            model.progressIndex == model.plannedSteps.count - 1
        )
    }
}
