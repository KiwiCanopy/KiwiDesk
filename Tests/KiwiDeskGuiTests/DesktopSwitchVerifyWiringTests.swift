import Foundation
import Testing

/// The #1023 verify's schedule→body WIRING. `DesktopCommandTests`
/// proves the arm (`isScheduled`) and `DesktopSwitchGuardTests`
/// the body (`verifyDesktopSwitch`), but neither can see whether
/// the deferred closure still CALLS the body — deleting that one
/// line leaves both green (the gui.md #1011 lesson: a suite
/// reading what the body declares cannot see what it is wired
/// to, so the wiring gets a guard of its own). A scan rather
/// than an await, deliberately: awaiting the real 600 ms task
/// would hold the process-global `currentSpaceOverride` across a
/// suspension, which the command suites' arrangement forbids.
@Suite("Desktop switch verify wiring (#1023)")
struct DesktopSwitchVerifyWiringTests {
    @Test("The deferred closure calls the verify body")
    func closureCallsTheBody() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let file = root.appendingPathComponent(
            "Sources/KiwiDeskCore/Commands/"
                + "KiwiCore+DesktopSwitch.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        // ONE contiguous needle from the key through the call
        // (the KeyboardConflictWiringTests idiom): two disjoint
        // needles pass with the call moved OUT of the closure,
        // which is the exact gap this suite names. The delay
        // value inside it is glue holding the needle contiguous,
        // not an assertion — a retune edits this test knowingly.
        let needle = """
            deferred.schedule(
                        .desktopSwitchVerify,
                        after: .milliseconds(600)
                    ) { [weak self] in
                        guard let self, self.eventLoop.isRunning else {
                            return
                        }
                        self.verifyDesktopSwitch(to: target, verb: verb)
                    }
            """
        #expect(
            normalized(source).occurrences(of: normalized(needle))
                == 1
        )
    }

    /// Whitespace-insensitive form, so the needle pins the token
    /// SEQUENCE (key → closure → call) rather than the
    /// formatter's current line breaks.
    private func normalized(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
