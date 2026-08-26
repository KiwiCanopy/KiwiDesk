import Foundation
import Testing

/// The production wirings of the followed-departure focus
/// (#1007) that no unit test reaches.
///
/// `FollowFocusIntentTests` holds what the record DOES against
/// an injected clock, and `DesktopSwitchGuardTests` drives the
/// record→pay path end-to-end through the dispatch and the
/// fold. What neither can see is the SHAPE each wiring must
/// keep: the payer sits behind live AX and a real `focusWindow`,
/// the re-key behind a native-tab flow no unit fixture builds —
/// delete one and the suites stay green while the follow
/// silently goes back to landing focus on a window of the space
/// the user asked to leave.
///
/// Each needle is pinned by EXACT COUNT and to its file, because
/// this seam fails in both directions: a second recorder would
/// owe a focus nobody drains, and zero of any of them is the
/// defect back.
@Suite("The followed-departure focus stays wired (#1007)")
struct FollowFocusSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// needle → the file that may carry it.
    ///
    /// A map rather than three tests: they are one fact — the
    /// record is written, drained and re-keyed, each in one
    /// place — and a reader who adds a fourth site should meet
    /// the list rather than a fourth copy of the same assertion.
    private static let wirings: [(String, String)] = [
        // The recorder: only a follow whose switch HAPPENED owes
        // a focus, so this is inside `moveToDesktop`'s follow
        // branch behind its `.switched` gate.
        ("followFocus.record(", "KiwiCore+DesktopCommands.swift"),
        // The drain, at the ARRIVAL — the moment the window
        // re-materializes, which is when it becomes addressable
        // again. Keyed to that window rather than to the reveal,
        // so no unrelated switch can pay the debt. It lives
        // inside `payFollowedFocus(arrived:)`, whose one caller
        // is the `.windowCreated` arm — pinned below.
        ("followFocus.claim(", "KiwiCore+DisplayFocus.swift"),
        // A guard-prover round on the parked branch deleted this
        // and found every guard green — the rekey tests spend
        // themselves on BEHAVIOUR, which cannot see whether
        // anything calls it. A re-key mid-flight otherwise
        // leaves the debt naming a dead id and the follow
        // silently drops (#308).
        ("followFocus.rekey(", "KiwiCore+RekeyEvent.swift"),
    ]

    @Test("each wiring exists exactly once, in its own file")
    func wiringsAreSingular() throws {
        for (needle, file) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            #expect(
                sites.count == 1,
                """
                expected exactly one `\(needle)`, found \
                \(sites.count): \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
            #expect(
                sites.allSatisfy {
                    $0.file.lastPathComponent == file
                },
                .init(
                    rawValue: "`\(needle)` belongs in \(file), "
                        + "found in "
                        + sites.map(\.site)
                        .joined(separator: ", ")
                )
            )
        }
    }

    /// A follow is a space SWITCH, not a focus call.
    ///
    /// Focusing the window without activating its space leaves
    /// `focusedWindowID` — the implicit target of nearly every
    /// command — naming the anchor of the space the user just
    /// left, and emits no `space_change`. That shipped in the
    /// parked branch's first draft and review caught it; the
    /// three calls are pinned together because any one of them
    /// alone is the half-fix.
    @Test("paying the debt activates the space, not just the window")
    func payingIsASpaceSwitch() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Commands")
                .appendingPathComponent("KiwiCore+DisplayFocus.swift")
        )
        guard
            let payer = SourceScan.declarationBody(
                after: "func payFollowedFocus",
                in: source
            )
        else {
            Issue.record("no payFollowedFocus in KiwiCore+DisplayFocus")
            return
        }
        #expect(
            payer.contains("followFocus.claim(if:"),
            """
            the payer owns the claim, so the arrival is the one \
            place a debt can be paid
            """
        )
        for call in [
            "state.workspaces.activate(",
            "focusWindow(",
            "emitSpaceChange()",
        ] {
            #expect(
                payer.contains(call),
                .init(
                    rawValue: "paying a follow's debt owes "
                        + "\(call) — without it the user types "
                        + "on one screen while commands act on "
                        + "the space they left"
                )
            )
        }
    }

    /// Only a switch that actually happened owes a focus.
    ///
    /// `.alreadyShown` produces no vanish and no reveal, so a
    /// debt recorded there would never be paid — it would sit
    /// live until its bound. `.refused` never took the user
    /// anywhere at all. A guard-prover round on the parked
    /// branch moved the recorder out of its gate and nothing
    /// red, which is why the gate is read rather than trusted.
    @Test("only a switch that happened records a debt")
    func onlyASwitchRecords() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Commands")
                .appendingPathComponent(
                    "KiwiCore+DesktopCommands.swift"
                )
        )
        guard
            let gated = SourceScan.declarationBody(
                after: "if case .switched = outcome",
                in: source
            )
        else {
            Issue.record(
                """
                moveToDesktop no longer gates the recorder on \
                the switch outcome
                """
            )
            return
        }
        #expect(
            gated.contains("followFocus.record("),
            """
            the recorder belongs INSIDE the switched gate: a \
            Desktop already shown produces no reveal, so a debt \
            recorded there is never drained.
            """
        )
    }

    /// The arrival is the drain's ONE caller.
    ///
    /// `payFollowedFocus(arrived:)` is a no-op unless the window
    /// named is the one owed, so a second caller would not
    /// misbehave — it would mean some other moment had been
    /// nominated as "the window is addressable again", which is
    /// the judgement this fix rests on.
    @Test("the arrival is where the debt is paid")
    func theArrivalPaysTheDebt() throws {
        let sites = try SourceScan.identifierSites(
            of: "payFollowedFocus(arrived:",
            under: Self.core
        )
        #expect(
            sites.count == 1,
            .init(
                rawValue: "one call expected, found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
        #expect(
            sites.allSatisfy {
                $0.file.lastPathComponent == "KiwiCore+Events.swift"
            }
        )
    }
}
