import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// General's gate resolver (#678 turn 14b).
///
/// The area's two gates are the login toggle and the
/// crash-restart row, and both became answerable only when the
/// `SMAppService` status was lifted out of `LoginItemCard` — see
/// `GeneralGates` for why that mattered.
@Suite("General gates")
struct GeneralGateTests {
    private func status(
        _ level: AutoStartLevel,
        registerable: Bool = true
    ) -> AutoStartStatus {
        AutoStartStatus(
            level: level,
            unavailable: registerable ? nil : .notBundled,
            requiresApproval: false
        )
    }

    /// The declared-vs-answered split, read off the census rather
    /// than restated: a new gated row in this area that lands in
    /// neither set reds here rather than failing open at runtime.
    @Test("every gated row is resolved somewhere")
    func everyGatedRowIsResolved() {
        let gated = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .general
                    && $0.placement.gate != nil
            }
        )
        #expect(
            gated
                == GeneralGates.resolved
                .union(GeneralGates.resolvedElsewhere)
        )
        #expect(
            GeneralGates.resolved
                .isDisjoint(with: GeneralGates.resolvedElsewhere)
        )
    }

    /// An ungated row is never inert — the resolver's first guard,
    /// and what keeps its `default:` arm unreachable rather than
    /// merely believed to be.
    @Test("ungated rows stay live")
    func ungatedRowsStayLive() {
        let gates = GeneralGates(autoStart: status(.atLogin))
        for key in SettingKey.allCases
        where key.placement.area == .general
            && key.placement.gate == nil
        {
            #expect(gates.inertReason(for: key) == nil)
        }
    }

    @Test("an unregisterable copy greys both rows")
    func unregisterableGreysBoth() {
        let gates = GeneralGates(
            autoStart: status(.off, registerable: false)
        )
        #expect(
            gates.inertReason(for: .general(.startAtLogin))
                == .cannotRegister(.notBundled)
        )
    }

    /// Crash supervision is the CLI's since #1071, so the login
    /// switch answers for it: while the service is loaded it
    /// reads ON — KiwiDesk does start at login — and goes inert
    /// with the reason inline, because the login item would only
    /// add a second launcher racing the agent.
    @Test("the service makes the login switch inert")
    func serviceGreysTheLoginSwitch() {
        let served = GeneralGates(
            autoStart: status(.atLoginWithAutoRestart)
        )
        #expect(
            served.inertReason(for: .general(.startAtLogin))
                == .managedByService
        )
        // And live at the levels the GUI itself can set.
        for level in [AutoStartLevel.off, .atLogin] {
            let gates = GeneralGates(autoStart: status(level))
            #expect(
                gates.inertReason(for: .general(.startAtLogin))
                    == nil
            )
        }
    }

    /// An unregisterable copy outranks the service reason: it is
    /// the harder stop, and naming the service there would offer
    /// a fix that would not work either.
    @Test("cannot-register outranks the service reason")
    func unregisterableOutranksService() {
        let gates = GeneralGates(
            autoStart: status(
                .atLoginWithAutoRestart,
                registerable: false
            )
        )
        #expect(
            gates.inertReason(for: .general(.startAtLogin))
                == .cannotRegister(.notBundled)
        )
    }

    /// The greying and the refusal must agree: every state the
    /// resolver calls inert is one the setter would also refuse
    /// to produce. Derived over `allCases` rather than the two
    /// levels that exist today.
    @Test("what greys is what the setter refuses")
    func greyAndRefusalAgree() {
        for level in AutoStartLevel.allCases {
            let gates = GeneralGates(autoStart: status(level))
            let inert =
                gates.inertReason(
                    for: .general(.startAtLogin)
                ) != nil
            // The GUI can only change the login item from a
            // level it does not already own: while the service
            // holds it, the switch is inert AND the binding's
            // guard refuses. Grey and guard, one condition.
            let guarded = level == .atLoginWithAutoRestart
            #expect(
                inert == guarded,
                Comment(
                    rawValue:
                        "from \(level) the switch is "
                        + "\(inert ? "inert" : "live") but the "
                        + "setter would "
                        + "\(guarded ? "refuse" : "accept")"
                        + " — the grey and the guard disagree"
                )
            )
        }
    }

    /// The resolver is not merely declared — the two rows CONSULT
    /// it. A round-1 cut of turn 14b shipped `GeneralGates` and
    /// `GeneralGateHelp` constructed only in tests, while the views
    /// re-derived each greying predicate and re-authored each
    /// sentence inline; the census gate and the on-screen grey
    /// could then drift with every gate test still green. This
    /// reds if either row stops asking the resolver, or authors a
    /// gate sentence itself instead of reading `GeneralGateHelp`.
    ///
    /// Where a substring scan stops, stated so it is not mistaken
    /// for more: a gate key renamed to a SUPERSTRING (a suffix
    /// appended in `GeneralGateHelp`) is invisible to the
    /// `help.contains` half — `scripts/extract-keys` catches that
    /// key change instead, since `en.json` would no longer match.
    /// A re-authored key in a VIEW is still caught, because a
    /// superstring there also contains the checked stem. And the
    /// presence checks prove the two symbols are TEXT in the file,
    /// not that the live greying path reaches them — the resolver
    /// tests above own the behaviour; this owns the wiring.
    @Test("the row consults the resolver, not an inline copy")
    func rowsConsultTheResolver() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/General"
            )
        // One row since #1071: the Advanced restart row is
        // gone, crash supervision being the CLI's.
        let rows = ["LoginItemCard.swift"]
        func read(_ name: String) throws -> String {
            try String(
                contentsOf: dir.appendingPathComponent(name),
                encoding: .utf8
            )
        }
        for name in rows {
            let source = try read(name)
            #expect(
                source.contains("generalGates.inertReason"),
                Comment(
                    rawValue:
                        "\(name) no longer asks the gate resolver "
                        + "for its greying"
                )
            )
            #expect(
                source.contains("GeneralGateHelp.sentence"),
                Comment(
                    rawValue:
                        "\(name) does not read GeneralGateHelp for "
                        + "its inert caption"
                )
            )
        }
        // Every gate sentence is authored ONCE, in GeneralGateHelp;
        // a row that re-authors one is the duplication that let the
        // two rows describe one status two ways.
        let help = try read("GeneralGateHelp.swift")
        for key in [
            "general.login_item.managed_by_service",
            "general.login_item.unavailable",
            "general.login_item.unavailable_binary",
        ] {
            #expect(
                help.contains(key),
                Comment(rawValue: "GeneralGateHelp lost \(key)")
            )
            for name in rows {
                #expect(
                    !(try read(name)).contains(key),
                    Comment(
                        rawValue:
                            "\(name) re-authors \(key) — it must "
                            + "come from GeneralGateHelp"
                    )
                )
            }
        }
    }

    /// The newly-live help names the RIGHT fix per cause: the two
    /// unregisterable causes must not collapse to one sentence, or
    /// a bare-binary copy reads "move to Applications", advice that
    /// does not apply. Distinct, non-empty, and distinct from the
    /// login-dependency line.
    @MainActor
    @Test("each inert reason renders its own sentence")
    func eachReasonHasItsOwnSentence() {
        let translocated = GeneralGateHelp.sentence(
            for: .cannotRegister(.translocated)
        )
        let notBundled = GeneralGateHelp.sentence(
            for: .cannotRegister(.notBundled)
        )
        let managed = GeneralGateHelp.sentence(
            for: .managedByService
        )
        for sentence in [translocated, notBundled, managed] {
            #expect(!sentence.isEmpty)
        }
        #expect(translocated != notBundled)
        #expect(translocated != managed)
        #expect(notBundled != managed)
    }
}
