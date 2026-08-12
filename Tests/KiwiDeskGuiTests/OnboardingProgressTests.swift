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
        for wantsKeys in [true, false] {
            let model = OnboardingModel()
            model.hasSeparateSpaces = { false }
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

    /// The snapshot's promise, and its stated cost.
    ///
    /// The plan is resolved once, at `beginPresentation`, so a
    /// gate falsified mid-tour does not re-number the row under
    /// the reader — the row keeps its length and the marker
    /// advances past the screen the flow now skips. A recomputing
    /// plan would shorten while the user watched, which is the
    /// counter pass 11 banned in motion rather than at rest.
    ///
    /// Falsifies the INJECTED preference, never the host's: the
    /// first cut moved `displayCount` on a machine where the live
    /// pref already made the predicate false at both counts, so
    /// it compared two identical lists and the whole snapshot
    /// could be deleted with the suite green (`guard-prover`,
    /// 2026-08-12).
    @Test("a gate falsified mid-tour does not re-plan the row")
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

        // …and the flow, which does read the gate live, walks
        // past the step. The row still ends on its last pip.
        model.continueAfterKeys()
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
