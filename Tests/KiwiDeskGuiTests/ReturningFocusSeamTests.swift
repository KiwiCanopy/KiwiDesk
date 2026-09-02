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
/// arrival arm (it would then read a focus the burst already
/// walked off), the mirror moved out of the create block, the
/// settle's refocus no longer gated on the debt, the payer
/// reduced to the state stamp (the narration survives), the
/// re-key deleted.
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
        ("rekeyDesktopFocus(old: old, new: new)", "KiwiCore+RekeyEvent.swift"),
        // The arrival arm owes; the mirror hands the fold the
        // owed window; the payer is called once, by the arrival.
        ("oweDesktopFocus(for:", "KiwiCore+Desktops.swift"),
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
    /// first-in-row again.
    @Test("the debt has its two readers")
    func theDebtHasItsTwoReaders() throws {
        let sites = try SourceScan.identifierSites(
            of: "desktopMemory.returnFocus.owed(",
            under: Self.core
        )
        let files = Set(sites.map(\.file.lastPathComponent))
        #expect(
            sites.count == 2
                && files == [
                    "KiwiCore+Events.swift",
                    "KiwiCore+Desktops.swift",
                ],
            .init(
                rawValue: "expected the mirror and the settle, "
                    + "found "
                    + sites.map(\.site)
                    .joined(separator: ", ")
            )
        )
    }

    /// The #634 arrangement reset forgets the memory beside
    /// `rememberedSpaces`, the id-keyed map it mirrors: after a
    /// reset every stale entry is "gone from state" and would be
    /// owed on the next return.
    @Test("the arrangement reset forgets the memory")
    func theResetForgetsTheMemory() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("App")
                .appendingPathComponent("KiwiCore+Reset.swift")
        )
        guard
            let reset = SourceScan.declarationBody(
                after: "func discardSavedArrangement",
                in: source
            )
        else {
            Issue.record("discardSavedArrangement missing")
            return
        }
        #expect(reset.contains("state.forgetRememberedSpaces()"))
        #expect(reset.contains("forgetDesktopFocus()"))
    }

    /// A debt lives from one return to the next: the arrival arm
    /// retires the last one BEFORE it decides whether to owe, or
    /// a Desktop that owes nothing inherits the previous return's
    /// hold on its vacancy and settle.
    @Test("the last debt is retired before a new one is owed")
    func theLastDebtIsRetiredFirst() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Profiles")
                .appendingPathComponent(Self.memoryFile)
        )
        guard
            let owe = SourceScan.declarationBody(
                after: "func oweDesktopFocus",
                in: source
            ),
            let forget = owe.range(of: "returnFocus.forget()"),
            let record = owe.range(of: "returnFocus.record(")
        else {
            Issue.record("oweDesktopFocus no longer forgets and records")
            return
        }
        #expect(
            forget.lowerBound < record.lowerBound,
            "the retire precedes the decision to owe"
        )
    }

    /// The recorder runs in the DEPARTURE arm — beside the Space
    /// memory's own write, from the same snapshot key, before the
    /// handler returns and the burst folds the departed windows.
    /// Recorded anywhere later it reads a focus the walk already
    /// moved, which is the defect itself.
    @Test("the focus is remembered in the departure arm")
    func rememberedInTheDepartureArm() throws {
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
            let departure = SourceScan.declarationBody(
                after: "if let last = lastDesktop, last != number",
                in: handler
            )
        else {
            Issue.record(
                "handleDesktopChange no longer gates a departure"
            )
            return
        }
        #expect(
            departure.contains("rememberDesktopFocus("),
            "the recorder belongs INSIDE the departure arm"
        )
        #expect(
            departure.contains("rememberVirtualSpace("),
            "the recorder sits beside the Space memory's write"
        )
        let rest = handler.replacingOccurrences(
            of: departure,
            with: ""
        )
        #expect(
            !rest.contains("rememberDesktopFocus("),
            "the recorder may exist only inside the departure arm"
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
