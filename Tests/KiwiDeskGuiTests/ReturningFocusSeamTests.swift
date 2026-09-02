import Foundation
import Testing

/// The production wirings of the Desktop return's focus memory
/// (#1207) that no unit test reaches — the `FollowFocusSeamTests`
/// shape, for the second `FollowFocusIntent` instance.
///
/// `ReturningFocusFoldTests` holds what the fold DOES with the
/// owed window and `DesktopFocusMemoryTests` drives the
/// remember→owe→pay path through the real handler. What neither
/// can see is the SHAPE each wiring must keep — a violation that
/// leaves the behavior suites green: the recorder moved into the
/// switch handler (it would then read a focus a fast app's
/// destroys already walked off), the mirror moved out of the create block, the
/// settle's refocus no longer gated on the debt, the payer
/// reduced to the state stamp (the narration survives), the
/// re-key deleted, the retire moved behind the record, the
/// follow's precedence read a second time or not at all.
///
/// Each needle is pinned by EXACT COUNT and to its file, because
/// this seam fails in both directions: a second recorder would
/// owe a focus nobody drains, and zero of any of them is the
/// defect back.
@Suite("The Desktop return's focus memory stays wired (#1207)")
struct ReturningFocusSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )
    private static let memoryFile = "KiwiCore+DesktopFocusMemory.swift"

    /// needle → the file that may carry it.
    private static let wirings: [(String, String)] = [
        // The debt: recorded only by the arrival arm's owe, which
        // reads the memory under the switch's own key.
        ("desktopMemory.returnFocus.record(", memoryFile),
        // The drain, at the owed window's ARRIVAL — inside
        // `payReturningFocus(arrived:)`, whose one caller is the
        // `.windowCreated` arm (pinned below).
        ("desktopMemory.returnFocus.claim(", memoryFile),
        // A re-key mid-flight otherwise leaves the debt naming a
        // dead id and the return silently drops (#308).
        ("desktopMemory.returnFocus.rekey(", memoryFile),
        // A window gone for good can never arrive (#1146): the
        // id-keyed retire in `retireAwayDebts`, reached by the
        // census prune and the app's exit.
        ("desktopMemory.returnFocus.retire(", "KiwiCore+AwayWindows.swift"),
        ("rekeyDesktopFocus(old: old, new: new)", "KiwiCore+RekeyEvent.swift"),
        // The arrival arm owes; the mirror hands the fold the
        // owed window; the payer is called once, by the arrival.
        // The recorder: the honored focus REPORT, and nowhere
        // else — never a fold, never the switch handler.
        ("rememberHonoredFocus(id)", "KiwiCore+FocusEvents.swift"),
        // The precedence: a standing follow (#1007) is read once,
        // where the return decides whether to owe.
        ("followFocus.owed(", memoryFile),
        ("state.returningFocus =", "KiwiCore+Events.swift"),
        ("payReturningFocus(arrived:", "KiwiCore+Events.swift"),
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

    /// The debt is READ in exactly two places: the mirror before
    /// the create fold and the settle's stand-down. A third
    /// reader would be a new moment nominated as "pay or hold",
    /// which is the judgement this fix rests on; one fewer is a
    /// fold that never learns the debt, or a settle that raises
    /// The debt is READ in exactly three places: the mirror
    /// before the create fold, the settle's stand-down, and the
    /// honored-focus retire (a focus honored in the active space
    /// while a debt stands is the OS's or the user's own choice,
    /// which the memory yields to). A fourth reader would be a new
    /// moment nominated as "pay, hold or yield", which is the
    /// judgement this fix rests on; one fewer is a fold that never
    /// learns the debt, a settle that raises first-in-row again,
    /// or a payment over a fresher focus.
    @Test("the debt has its three readers")
    func theDebtHasItsThreeReaders() throws {
        let sites = try SourceScan.identifierSites(
            of: "desktopMemory.returnFocus.owed(",
            under: Self.core
        )
        let files = Set(sites.map(\.file.lastPathComponent))
        #expect(
            sites.count == 3
                && files == [
                    "KiwiCore+Events.swift",
                    "KiwiCore+Desktops.swift",
                    Self.memoryFile,
                ],
            .init(
                rawValue: "expected the mirror, the settle and "
                    + "the retire, found "
                    + sites.map(\.site)
                    .joined(separator: ", ")
            )
        )
    }

    /// The owe runs in the switch handler's ARRIVAL arm, once,
    /// after the arriving space is activated — the one place that
    /// knows both the target and the Desktop number.
    @Test("the owe runs once, in the arrival arm")
    func theOweRunsInTheArrivalArm() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Profiles")
                .appendingPathComponent("KiwiCore+Desktops.swift")
        )
        guard
            let handler = SourceScan.declarationBody(
                after: "func handleDesktopChange",
                in: source
            ),
            let activate = handler.range(
                of: "state.workspaces.activate(target)"
            ),
            let owe = handler.range(of: "oweReturningFocus(")
        else {
            Issue.record(
                "handleDesktopChange no longer activates and owes"
            )
            return
        }
        #expect(
            activate.lowerBound < owe.lowerBound,
            "the owe follows the activation of the arriving space"
        )
        let rest = source.replacingOccurrences(of: handler, with: "")
        #expect(
            !rest.contains("oweReturningFocus("),
            "the owe lives in the handler and nowhere else"
        )
        let sites = try SourceScan.identifierSites(
            of: "oweReturningFocus(",
            under: Self.core
        )
        // The definition and its one call.
        #expect(sites.count == 2)
    }

    /// The recorder runs at the honored focus REPORT — after the
    /// handler has ruled the report honored, and never inside the
    /// switch handler: the device showed a fast app's destroys
    /// folding BEFORE the notification, so a handler-time read
    /// remembers a focus the walk already moved.
    @Test("the focus is remembered at the honored report, not the switch")
    func rememberedAtTheHonoredReport() throws {
        let events = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("App")
                .appendingPathComponent("KiwiCore+FocusEvents.swift")
        )
        guard
            let handler = SourceScan.declarationBody(
                after: "func handleWindowFocused",
                in: events
            ),
            let honored = handler.range(of: "honored; "),
            let record = handler.range(of: "rememberHonoredFocus(")
        else {
            Issue.record(
                "handleWindowFocused no longer narrates and records"
            )
            return
        }
        #expect(
            honored.lowerBound < record.lowerBound,
            "the record follows the honored verdict"
        )
        let desktops = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Profiles")
                .appendingPathComponent("KiwiCore+Desktops.swift")
        )
        #expect(
            !desktops.contains("honoredFocus[")
                && !desktops.contains("rememberHonoredFocus("),
            "the switch handler records nothing"
        )
    }

    /// The mirror is written in the `.windowCreated` block that
    /// mirrors `arrivalDisplay`, so the fold reads the debt on
    /// every create and on nothing else.
    @Test("the mirror rides the create block")
    func theMirrorRidesTheCreateBlock() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("App")
                .appendingPathComponent("KiwiCore+Events.swift")
        )
        guard
            let block = SourceScan.declarationBody(
                after: "if case .windowCreated(let window) = event",
                in: source
            )
        else {
            Issue.record("handle no longer mirrors per create")
            return
        }
        #expect(block.contains("state.returningFocus ="))
        #expect(block.contains("state.arrivalDisplay ="))
    }

    /// Paying is the settle's own raise, not a state stamp: the
    /// fold already stamped `Space.focused`, and without the
    /// raise macOS's key window and KiwiDesk's focus diverge
    /// until the first click (#1130's class).
    @Test("the payer claims the debt and raises")
    func thePayerClaimsAndRaises() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Profiles")
                .appendingPathComponent(Self.memoryFile)
        )
        guard
            let payer = SourceScan.declarationBody(
                after: "func payReturningFocus",
                in: source
            )
        else {
            Issue.record("payReturningFocus missing")
            return
        }
        #expect(payer.contains("returnFocus.claim(if:"))
        #expect(
            payer.contains("effects.paidReturningFocus"),
            "the payer pays only what the fold said it paid"
        )
        #expect(payer.contains("focusWindow("))
    }

    /// The settle's refocus is gated on the debt: read the debt,
    /// and only in its absence raise `Space.focused` — raising
    /// it while the owed window is still unlisted IS the
    /// first-in-row jump the settle used to assert.
    @Test("the settle reads the debt before it refocuses")
    func theSettleReadsTheDebtFirst() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Profiles")
                .appendingPathComponent("KiwiCore+Desktops.swift")
        )
        guard
            let settle = SourceScan.declarationBody(
                after: "func desktopSettle",
                in: source
            ),
            let owed = settle.range(of: "returnFocus.owed()"),
            let raise = settle.range(of: "focusWindow(")
        else {
            Issue.record(
                "desktopSettle no longer reads the debt and raises"
            )
            return
        }
        #expect(
            owed.lowerBound < raise.lowerBound,
            "the debt is read before the settle's raise"
        )
        // The raise is the debt's ELSE: the two are one
        // `if … else if` chain, never two independent statements.
        let between = settle[owed.upperBound..<raise.lowerBound]
        #expect(
            between.contains("} else if"),
            "the settle raises only where no debt is owed"
        )
    }
}
