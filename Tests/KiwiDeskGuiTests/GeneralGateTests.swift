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
        // Not `.loginOff`: naming the login dependency would send
        // the reader to a row that is itself dead.
        #expect(
            gates.inertReason(
                for: .general(.advancedRestartOnCrash)
            ) == .cannotRegister(.notBundled)
        )
    }

    @Test("crash-restart is inert while login is off")
    func restartNeedsLogin() {
        let off = GeneralGates(autoStart: status(.off))
        #expect(
            off.inertReason(
                for: .general(.advancedRestartOnCrash)
            ) == .loginOff
        )
        // And live once login is on, at either level.
        for level in [
            AutoStartLevel.atLogin, .atLoginWithAutoRestart,
        ] {
            let on = GeneralGates(autoStart: status(level))
            #expect(
                on.inertReason(
                    for: .general(.advancedRestartOnCrash)
                ) == nil
            )
            #expect(
                on.inertReason(for: .general(.startAtLogin))
                    == nil
            )
        }
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
                    for: .general(.advancedRestartOnCrash)
                ) != nil
            // Asking for restart from this level: if the row is
            // inert, the fold must drop the request.
            let asked = AutoStartLevel.level(
                openAtLogin: level.opensAtLogin,
                restartOnCrash: true
            )
            #expect(
                inert == !asked.restartsOnCrash,
                Comment(
                    rawValue:
                        "from \(level) the row is "
                        + "\(inert ? "inert" : "live") but "
                        + "the setter would "
                        + "\(asked.restartsOnCrash ? "honour" : "drop")"
                        + " a restart request — the grey and "
                        + "the guard disagree"
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
    @Test("both rows consult the resolver, not an inline copy")
    func rowsConsultTheResolver() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/General"
            )
        let rows = [
            "LoginItemCard.swift", "GeneralRestartRow.swift",
        ]
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
            "general.advanced.restart_on_crash.needs_login",
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
        let loginOff = GeneralGateHelp.sentence(for: .loginOff)
        for sentence in [translocated, notBundled, loginOff] {
            #expect(!sentence.isEmpty)
        }
        #expect(translocated != notBundled)
        #expect(translocated != loginOff)
        #expect(notBundled != loginOff)
    }
}
