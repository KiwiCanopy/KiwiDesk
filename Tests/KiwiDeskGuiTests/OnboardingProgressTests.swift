import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's progress row is DERIVED from the steps this machine
/// will show (#828), which is a different claim from the fixed
/// counter #678 Phase 4 pass 11 banned: "step 3 of 5" is a lie on
/// a machine that shows three steps, and this suite is what keeps
/// the row from becoming one again.
///
/// **Every fixture pins BOTH halves of the Displays gate** — the
/// count and the "Displays have separate Spaces" preference. The
/// preference is a live `CFPreferences` read in production, and a
/// machine whose owner has already turned it off answers `false`
/// at every display count: on such a host this suite's first cut
/// passed with the step deleted from every plan and with the
/// snapshot removed outright (`guard-prover`, 2026-08-12). A test
/// whose verdict moves with the author's Mac is not a guard.
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
        // The axis is the one conditional step there is. The
        // first cut looped over `wantsKeys`, a seam deleted
        // earlier in the branch, so both iterations ran the same
        // route — and the fixture pinned the Displays gate OFF,
        // which meant the one net for plan-versus-route
        // disagreement never ran on the arm where a disagreement
        // is possible (architecture review, 2026-08-12).
        for (separate, displays) in [(true, 2), (false, 1)] {
            let model = OnboardingModel()
            model.hasSeparateSpaces = { separate }
            model.displayCount = { displays }
            model.beginPresentation(at: .grant)

            let planned = model.plannedSteps
            var walked: [OnboardingModel.Step] = [model.step]
            // BOUNDED, because a walk driven by the model's own
            // transitions is a walk that can stop advancing: a
            // `beginPresentation` that sets the step and forgets
            // the plan leaves `advance()` correctly doing
            // nothing, and this loop spun for seven minutes
            // instead of failing (`guard-prover`, 2026-08-12).
            // The cap is the longest tour there can be, so
            // reaching it IS the failure rather than a timeout
            // somebody has to interpret.
            var guardRail = OnboardingModel.Step.allCases.count
            while model.step != .done, guardRail > 0 {
                guardRail -= 1
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
                guardRail > 0,
                Comment(
                    rawValue: "the walk never reached .done — "
                        + "advance() stopped moving at "
                        + "\(model.step)"
                )
            )

            #expect(
                planned == walked,
                Comment(
                    rawValue: "separate \(separate), displays "
                        + "\(displays): planned \(planned) "
                        + "walked \(walked)"
                )
            )
        }
        // Vacuity: the two arms must differ, or the sweep is one
        // route run twice — which is exactly what it was.
        let long = OnboardingModel()
        long.hasSeparateSpaces = { true }
        long.displayCount = { 2 }
        long.beginPresentation(at: .grant)
        let short = OnboardingModel()
        short.hasSeparateSpaces = { false }
        short.displayCount = { 1 }
        short.beginPresentation(at: .grant)
        #expect(long.plannedSteps != short.plannedSteps)
    }

    /// Vacuity, and the whole point: two machines get two plans.
    /// A row that returned `Step.allCases` — the fixed counter,
    /// wearing a derivation's name — passes every test above.
    ///
    /// The axis is the Displays recommendation, the flow's one
    /// remaining conditional step (#828 made the keys step
    /// unconditional). Both arms are driven from the injected
    /// preference, so the verdict does not move with the machine
    /// the suite runs on.
    @Test("the plan's length varies with the machine")
    func planLengthIsNotConstant() {
        let recommended = OnboardingModel()
        recommended.hasSeparateSpaces = { true }
        recommended.displayCount = { 2 }
        recommended.beginPresentation(at: .grant)

        let plain = OnboardingModel()
        plain.hasSeparateSpaces = { false }
        plain.displayCount = { 1 }
        plain.beginPresentation(at: .grant)

        #expect(
            recommended.plannedSteps.count
                == plain.plannedSteps.count + 1
        )
        #expect(
            plain.plannedSteps.count
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
        model.hasSeparateSpaces = { false }
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
        model.hasSeparateSpaces = { false }
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

    /// The snapshot's promise, now that the plan IS the
    /// itinerary.
    ///
    /// A gate falsified mid-tour changes neither the row nor the
    /// route: the presentation keeps the list it opened with, and
    /// `advance()` walks that list. Before the collapse
    /// (architecture review, 2026-08-12) the flow re-asked the
    /// predicate while the row did not, so an unplugged display
    /// made the tour skip a screen the row still counted — the
    /// marker jumped two pips, which this suite recorded as a
    /// stated cost rather than a defect. There is no such cost
    /// now, and no way to construct the disagreement.
    ///
    /// Falsifies the INJECTED preference, never the host's: the
    /// first cut moved `displayCount` on a machine where the live
    /// pref already made the predicate false at both counts, so
    /// it compared two identical lists and the whole snapshot
    /// could be deleted with the suite green (`guard-prover`,
    /// 2026-08-12).
    @Test("a gate falsified mid-tour changes neither row nor route")
    func theRowDoesNotRePlanUnderTheReader() {
        let model = OnboardingModel()
        var separate = true
        model.hasSeparateSpaces = { separate }
        model.displayCount = { 2 }
        model.beginPresentation(at: .keys)
        let planned = model.plannedSteps
        #expect(planned.contains(.separateSpaces))

        separate = false
        #expect(model.plannedSteps == planned)

        // The route follows the plan, so the screen the tour
        // promised is the screen it shows.
        model.continueAfterKeys()
        #expect(model.step == .separateSpaces)
        #expect(model.progressIndex == 1)
        model.continueAfterSeparateSpaces()
        #expect(model.step == .done)
        #expect(
            model.progressIndex == model.plannedSteps.count - 1
        )
    }

    /// The Displays recommendation, pinned in BOTH directions
    /// from the injected preference rather than from the live
    /// one.
    ///
    /// The first cut derived its expectation from the same call
    /// the production code makes, so one side of the `==` was
    /// always the other: it could only ever catch a plan that
    /// stopped consulting the predicate, in whichever direction
    /// the host is not. On the author's Mac — separate Spaces
    /// off — deleting the step from every plan stayed green
    /// (`guard-prover`, 2026-08-12).
    @Test("the Displays recommendation counts when it fires")
    func displaysRecommendationCountsWhenItFires() {
        for (separate, displays, wanted) in [
            (true, 2, true),
            (false, 2, false),
            (true, 1, false),
            (false, 1, false),
        ] {
            let model = OnboardingModel()
            model.hasSeparateSpaces = { separate }
            model.displayCount = { displays }
            model.beginPresentation(at: .grant)

            #expect(
                model.plannedSteps.contains(.separateSpaces)
                    == wanted,
                Comment(
                    rawValue: "separate \(separate), displays "
                        + "\(displays): \(model.plannedSteps)"
                )
            )
        }
    }

    /// Progress reads as progress: each Continue moves the index
    /// forward by exactly one, and the last step is the last
    /// index. A plan that grew or reordered mid-tour would show
    /// the pill jumping or standing still.
    @Test("the index advances one step at a time to the end")
    func indexAdvancesMonotonically() {
        let model = OnboardingModel()
        model.hasSeparateSpaces = { false }
        model.displayCount = { 1 }
        model.beginPresentation(at: .grant)

        var seen: [Int?] = [model.progressIndex]
        // Bounded for `planMatchesTheWalkedRoute`'s reason: a
        // model that stops advancing must fail this test, not
        // hang it.
        var guardRail = OnboardingModel.Step.allCases.count
        while model.step != .done, guardRail > 0 {
            guardRail -= 1
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
        #expect(guardRail > 0, "the walk never reached .done")

        #expect(seen == (0..<seen.count).map { Int?($0) })
        #expect(
            model.progressIndex == model.plannedSteps.count - 1
        )
    }
}
