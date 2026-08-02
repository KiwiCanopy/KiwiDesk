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
///   `floatRaiseFloor`.** Its argument — that the floor excludes
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
        _ path: StaticString = #filePath
    ) throws -> String {
        let url = SourceScan.repoRoot(from: "\(path)")
            .appendingPathComponent("Sources/KiwiDeskCore/Commands")
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

    @Test("The float raise derives its floor through the rule")
    func floatRaiseUsesTheFloorRule() throws {
        let source = try body(
            of: "raiseFloatsAndSticky",
            in: "KiwiCore+ZOrderFloats.swift"
        )
        #expect(source.contains("floatRaiseFloor("))
    }
}
