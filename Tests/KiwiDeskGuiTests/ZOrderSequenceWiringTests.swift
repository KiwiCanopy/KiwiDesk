import Foundation
import Testing

/// The two decisions in a z-order raise sequence that **no unit
/// test can reach**, because their function needs live
/// `AXUIElement`s and returns before doing anything without them.
/// Both were found by removing them and watching the whole suite
/// stay green (`guard-prover`, 2026-08-02), and both are device-QA
/// regressions the owner has already hit once:
///
/// - **The drain's raised set must release the other stamps.**
///   `stampZOrderRaise` marks every target as "an echo is coming",
///   and `KiwiCore+FocusEvents` reverts the first focus report
///   from a stamped window. Since the sequence raises only what is
///   out of place, most of a pile is stamped and never raised, so
///   nothing consumes those stamps and each one swallows the
///   user's next CLICK on that window for a second. The unit test
///   proves `releaseZOrderStamps` does the right thing; nothing
///   but this proves it is called.
/// - **The float raise must derive its floor through
///   `raiseFloor`.** Its argument — that the floor excludes
///   the focused window because no quiet raise can beat the key
///   window — lives on that function with the measurement behind
///   it. Inlining a floor here would be invisible: no test in
///   either target calls `raiseFloatsAndSticky`.
///
/// A **presence** scan, so deleting the call reds. That is the
/// polarity that works: a containment guard is inert when the
/// failure is a missing element, and here the failure IS the
/// missing call.
///
/// **What it still cannot see**, stated so the next reader does
/// not mistake green here for coverage: it matches source text,
/// so it verifies that the named call appears with the named
/// argument, never that the value is *correct*. A right call with
/// a wrong argument, or a same-named helper doing something else,
/// passes. The semantics live in the unit tests
/// (`floatFloorExcludesTheFocusedWindow`,
/// `unraisedStampsAreReleased`) — this suite only answers "is it
/// wired", which is the half that was free to regress.
@Suite("Z-order sequence wiring (#684)")
struct ZOrderSequenceWiringTests {

    private func body(
        of function: String,
        in file: String,
        under directory: String = "Commands",
        _ path: StaticString = #filePath
    ) throws -> String {
        let url = SourceScan.repoRoot(from: "\(path)")
            .appendingPathComponent("Sources/KiwiDeskCore")
            .appendingPathComponent(directory)
            .appendingPathComponent(file)
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let characters = Array(source)
        let marker = Array("func \(function)(")
        guard
            let start = (0...(characters.count - marker.count))
                .first(where: { index in
                    Array(
                        characters[index..<(index + marker.count)]
                    ) == marker
                })
        else {
            Issue.record("\(function) not found in \(file)")
            return ""
        }
        // Past the signature, then the balanced body. The cursor
        // must land ON the opening paren first: `balanced` returns
        // nil without advancing when the next non-space character
        // is not its opener, which would silently reduce the walk
        // below to "the first `{` after the `func` keyword" — and
        // a signature carrying a brace (a defaulted closure
        // parameter) would then capture that instead of the body
        // (guard-prover, 2026-08-02).
        var cursor = start + marker.count - 1
        guard
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            ) != nil
        else {
            Issue.record("\(function): signature not balanced")
            return ""
        }
        while cursor < characters.count, characters[cursor] != "{" {
            cursor += 1
        }
        return SourceScan.balanced(
            characters,
            from: &cursor,
            open: "{",
            close: "}"
        ) ?? ""
    }

    @Test("The drain's completion releases the unraised stamps")
    func sequenceReleasesStamps() throws {
        let source = try body(
            of: "performZOrderSequence",
            in: "KiwiCore+ZOrderFloats.swift"
        )
        // Match the EDGE, not the two nodes. Both calls present
        // with nothing flowing between them is not a contrived
        // shape: `keeping: []` releases every stamp, including
        // those of windows whose echoes are still in flight, which
        // is the focus jump this branch already shipped once. A
        // two-string presence check passed that mutation
        // (guard-prover, 2026-08-02).
        #expect(source.contains("let raised = drain.run("))
        #expect(source.contains("keeping: raised"))
    }

    /// The live restore's policy, which nothing else can see.
    ///
    /// `zOrderDrain` is a private helper and no unit test reaches
    /// it, so handing it `.teardown` passed all 2424 tests
    /// (guard-prover, 2026-08-03) — and that swap is not cosmetic:
    /// it would hold the mouse warp for 2.5x as long through
    /// `zOrderRestoresInFlight`, and DROP the tail whose stamps
    /// nothing would then consume, which is the click-swallowing
    /// focus bug `releaseZOrderStamps` exists for.
    ///
    /// The unit suites pin what each policy MEANS
    /// (`exhaustedBudgetIssuesTheRemainder` reds if `.restore`
    /// stops issuing its tail); this pins which one arrives here.
    @Test("The float raise drains on the restore policy")
    func floatRaiseUsesTheRestorePolicy() throws {
        let source = try body(
            of: "zOrderDrain",
            in: "KiwiCore+ZOrderFloats.swift"
        )
        #expect(source.contains("policy: .restore"))
    }

    @Test("The float raise derives its floor through the rule")
    func floatRaiseUsesTheFloorRule() throws {
        let source = try body(
            of: "raiseFloatsAndSticky",
            in: "KiwiCore+ZOrderFloats.swift"
        )
        #expect(source.contains("raiseFloor("))
    }

    /// Monocle's floor is not an optimization, it is the whole
    /// raise: a lone target with no floor plans empty, so
    /// `restoreMonocleZOrder` shipped once raising nothing at all.
    /// The maths is pinned by `ZOrderRaisePlanTests`; this pins
    /// that this call site still asks for it, because the function
    /// is `private`, no unit test reaches it (`eventLoop
    /// .element(for:)` is nil under `makeTestCore`, so it returns
    /// before the drain), and reverting the argument to `above: []`
    /// re-ships the bug with every test green (code review,
    /// 2026-08-02).
    @Test("The monocle restore raises against a floor")
    func monocleRestoreUsesAFloor() throws {
        let source = try body(
            of: "restoreMonocleZOrder",
            in: "KiwiCore+ZOrder.swift"
        )
        #expect(source.contains("raiseFloor("))
    }

    /// The teardown restack is the one raise sequence that cannot
    /// self-heal — nothing runs after it — so it is also the one
    /// where reverting to a bare `AXHelper.raiseQuietly` loop
    /// leaves the user looking at the scramble permanently (#688).
    /// It is unreachable from a unit test for the same reason as
    /// the three above: `eventLoop.element(for:)` is nil under
    /// `makeTestCore`, so the function returns before the drain.
    ///
    /// The teardown restack's seams, bound to the real machine.
    ///
    /// This test used to carry the DECISIONS as well — seven scans
    /// re-typing `restackForTeardown`'s body, which red on renaming
    /// a local and pass on `budget * 2` (architect review,
    /// 2026-08-03). Those decisions moved behind seams into
    /// `TeardownRestack`, where `TeardownRestackTests` asserts them
    /// as behavior: the Accessibility gate, the dropped window, the
    /// per-group narrowing, the stop-dead boundary.
    ///
    /// What is left is the half no unit test in either target can
    /// reach, because `makeTestCore` has neither AX nor a
    /// WindowServer: that these four seams are bound to the real
    /// machine rather than to something inert. A `TeardownRestack`
    /// built with `isTrusted: { true }` and a drain factory
    /// returning nil satisfies every behavioral test in that suite
    /// and raises nothing at all on a real quit.
    @Test("The teardown restack binds the real seams")
    func teardownRestackUsesTheDrain() throws {
        let source = try body(
            of: "restackForTeardown",
            in: "KiwiCore+TeardownRaise.swift",
            under: "App"
        )
        #expect(source.contains("AXHelper.isTrusted()"))
        #expect(
            source.contains("trustedFrontmostFocusedWindowID()")
        )
        #expect(source.contains("teardownDrain("))
        #expect(source.contains("policy: .teardown"))
    }
}
