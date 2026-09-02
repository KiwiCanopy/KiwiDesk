import Foundation
import Testing

/// The production wirings of the followed-departure focus
/// (#1007) that no unit test reaches.
///
/// `FollowFocusIntentTests` holds what the record DOES against
/// an injected clock, and `DesktopFollowTests` drives the
/// record→pay path end-to-end through the dispatch and the
/// fold. What neither can see is the SHAPE each wiring must
/// keep — a violated obligation that leaves the behavior suites
/// green: the recorder moved out of its gate, the payer reduced
/// to a bare focus (the narration line survives), the re-key
/// deleted (a native-tab flow no unit fixture builds).
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
        ("followFocus.record(", "KiwiCore+DesktopMove.swift"),
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

    /// The follow's debt has ONE reader beyond its payer — the
    /// Desktop return's precedence (#1207), pinned in
    /// `ReturningFocusSeamTests`' register rather than here.
    /// And it is never FORGOTTEN: `forget()` is the return's
    /// (#1207) — the follow records only after a `.switched`
    /// outcome, so there is no refused switch to retire, and a
    /// forget on this instance would drop a debt the reveal is
    /// about to pay. A count over the tree, the fail-open-safe
    /// form of a negative clause (tests.md, #1021).
    @Test("the follow never forgets its debt")
    func theFollowNeverForgets() throws {
        let sites = try SourceScan.identifierSites(
            of: "followFocus.forget(",
            under: Self.core
        )
        #expect(
            sites.isEmpty,
            .init(
                rawValue: "the follow's debt is drained, never "
                    + "forgotten — found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }

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
    /// three calls are pinned together in the ONE hand-off both
    /// follow arms route through, because any one of them alone
    /// is the half-fix and a second hand copy is where the trio
    /// would drift apart (review round 1).
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
            ),
            let handOff = SourceScan.declarationBody(
                after: "func handFollowFocus",
                in: source
            )
        else {
            Issue.record(
                "payFollowedFocus/handFollowFocus missing"
            )
            return
        }
        #expect(
            payer.contains("followFocus.claim(if:"),
            """
            the payer owns the claim, so the arrival is the one \
            place a debt can be paid
            """
        )
        #expect(
            payer.contains("handFollowFocus("),
            "the payer routes through the one hand-off"
        )
        for call in [
            "state.workspaces.activate(",
            "focusWindow(",
            "emitSpaceChange()",
        ] {
            #expect(
                handOff.contains(call),
                .init(
                    rawValue: "the follow hand-off owes "
                        + "\(call) — without it the user types "
                        + "on one screen while commands act on "
                        + "the space they left"
                )
            )
        }
        // The already-shown arm routes through the SAME hand-off
        // (review round 1: the re-home stamps the destination's
        // focused member but never activates it, so a follow
        // onto a visible cross-screen Desktop left
        // `focusedWindowID` naming the space the user left).
        let commands = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Commands")
                .appendingPathComponent(
                    "KiwiCore+DesktopMove.swift"
                )
        )
        guard
            let shown = SourceScan.declarationBody(
                after: "case .alreadyShown",
                in: commands
            )
        else {
            Issue.record(
                "moveToDesktop no longer rules .alreadyShown"
            )
            return
        }
        #expect(
            shown.contains("handFollowFocus("),
            """
            the already-shown follow owes the state half of the \
            switch through the one hand-off
            """
        )
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
                    "KiwiCore+DesktopMove.swift"
                )
        )
        // The switched ARM is the span from its case label to
        // the next arm's — the case order is part of the needle
        // (glue holding it contiguous, not an assertion).
        guard
            let dispatch = SourceScan.declarationBody(
                after: "switch outcome",
                in: source
            ),
            let armStart = dispatch.range(of: "case .switched:"),
            let armEnd = dispatch.range(of: "case .alreadyShown:")
        else {
            Issue.record(
                """
                moveToDesktop no longer rules the switch \
                outcome arms
                """
            )
            return
        }
        let arm = dispatch[armStart.upperBound..<armEnd.lowerBound]
        #expect(
            arm.contains("followFocus.record("),
            """
            the recorder belongs INSIDE the switched arm: a \
            Desktop already shown produces no reveal, so a debt \
            recorded there is never drained.
            """
        )
        // …and nowhere else in the dispatch: a second recorder
        // outside the arm is the ungated shape this guard exists
        // to refuse.
        let rest = dispatch.replacingOccurrences(
            of: String(arm),
            with: ""
        )
        #expect(
            !rest.contains("followFocus.record("),
            "the recorder may exist only inside the switched arm"
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
