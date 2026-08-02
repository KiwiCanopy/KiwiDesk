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
        // Past the signature, then the balanced body.
        var cursor = start
        _ = SourceScan.balanced(
            characters,
            from: &cursor,
            open: "(",
            close: ")"
        )
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
        // The raised set has to be taken from the drain and handed
        // to the release — either half alone is the bug.
        #expect(source.contains("drain.run("))
        #expect(source.contains("releaseZOrderStamps("))
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
