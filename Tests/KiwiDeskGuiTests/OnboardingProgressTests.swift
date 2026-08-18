import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's progress row is DERIVED from the steps this
/// presentation will show (#828), which is a different claim from
/// the fixed counter #678 Phase 4 pass 11 banned: "step 2 of 4"
/// is a lie at a door that opens past the grant, and this suite
/// is what keeps the row from becoming one again.
///
/// The derivation's one axis is the DOOR since #888 retired the
/// separate-Spaces recommendation — the tour's last machine-gated
/// step. The plan-versus-flow discipline stays load-bearing all
/// the same: a plan and a flow reading different answers is the
/// disagreement that bit this tour twice (#828, and the
/// `wantsDiscovery` build before it), and a future machine-gated
/// step inherits these nets the day it lands.
@Suite("Onboarding progress row derivation (#828)")
@MainActor
struct OnboardingProgressTests {

    /// Advances the model along its own transitions until `.done`
    /// or the guard rail runs out. BOUNDED, because a walk driven
    /// by the model's own transitions is a walk that can stop
    /// advancing: a `beginPresentation` that sets the step and
    /// forgets the plan leaves `advance()` correctly doing
    /// nothing, and an unbounded loop spun for seven minutes
    /// instead of failing (`guard-prover`, 2026-08-12). The cap
    /// is the longest tour there can be, so reaching it IS the
    /// failure rather than a timeout somebody has to interpret.
    private func walk(
        _ model: OnboardingModel
    ) -> (steps: [OnboardingModel.Step], stalled: Bool) {
        var walked: [OnboardingModel.Step] = [model.step]
        var guardRail = OnboardingModel.Step.allCases.count
        while model.step != .done, guardRail > 0 {
            guardRail -= 1
            switch model.step {
            case .grant: model.continueAfterAccessibility()
            case .spaces: model.continueAfterSpaces()
            case .keys: model.continueAfterKeys()
            case .done: break
            }
            walked.append(model.step)
        }
        return (walked, guardRail == 0)
    }

    /// The claim the row makes, stated as a test: what it counts
    /// is what the user is then walked through.
    ///
    /// Driven through the model's OWN transitions rather than
    /// against a hand-written list — a plan derived from one copy
    /// of the route and a flow driven by another would agree in a
    /// test that wrote both down. The axis is the door, the one
    /// thing that still varies the plan.
    @Test("the plan is the route the tour actually walks")
    func planMatchesTheWalkedRoute() {
        for door: OnboardingModel.Step in [.grant, .spaces, .keys] {
            let model = OnboardingModel()
            model.beginPresentation(at: door)
            let planned = model.plannedSteps
            let (walked, stalled) = walk(model)
            #expect(
                !stalled,
                Comment(
                    rawValue: "the walk never reached .done — "
                        + "advance() stopped moving at "
                        + "\(model.step)"
                )
            )
            #expect(
                planned == walked,
                Comment(
                    rawValue: "door \(door): planned \(planned) "
                        + "walked \(walked)"
                )
            )
        }
    }

    /// Vacuity, and the whole point: two doors get two plans. A
    /// row that returned `Step.allCases` — the fixed counter,
    /// wearing a derivation's name — passes `planMatchesTheWalkedRoute`
    /// from the `.grant` door, and this is what reds it.
    ///
    /// A door that opens past a screen never counts it (#331's
    /// resumed tour, and Home's "Show me around" on a trusted
    /// Mac): a row counting from `.grant` there would open
    /// reading "2 of 4" on the tour's own first screen.
    @Test("steps before the entry door are not counted")
    func entryDoorTrimsThePlan() {
        let model = OnboardingModel()
        model.isTrusted = true
        model.beginPresentation(at: .spaces)

        #expect(!model.plannedSteps.contains(.grant))
        #expect(model.plannedSteps.first == .spaces)
        #expect(model.progressIndex == 0)
        #expect(
            model.plannedSteps.count
                < OnboardingModel.Step.allCases.count
        )
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
        model.beginPresentation(at: .grant)
        let before = model.plannedSteps

        model.isTrusted = true
        #expect(model.plannedSteps == before)
        #expect(model.progressIndex == 0)

        model.continueAfterAccessibility()
        #expect(model.plannedSteps == before)
        #expect(model.progressIndex == 1)
    }

    /// Progress reads as progress: each Continue moves the index
    /// forward by exactly one, and the last step is the last
    /// index. A plan that grew or reordered mid-tour would show
    /// the pill jumping or standing still.
    @Test("the index advances one step at a time to the end")
    func indexAdvancesMonotonically() {
        let model = OnboardingModel()
        model.beginPresentation(at: .grant)

        var seen: [Int?] = [model.progressIndex]
        var guardRail = OnboardingModel.Step.allCases.count
        while model.step != .done, guardRail > 0 {
            guardRail -= 1
            switch model.step {
            case .grant: model.continueAfterAccessibility()
            case .spaces: model.continueAfterSpaces()
            case .keys: model.continueAfterKeys()
            case .done: break
            }
            seen.append(model.progressIndex)
        }
        #expect(guardRail > 0, "the walk never reached .done")

        #expect(seen == (0..<seen.count).map { Int?($0) })
        #expect(
            model.progressIndex == model.plannedSteps.count - 1
        )
    }
}
