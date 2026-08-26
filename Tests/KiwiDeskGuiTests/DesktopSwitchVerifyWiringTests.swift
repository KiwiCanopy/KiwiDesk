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
        // Non-vacuous: the schedule exists…
        #expect(source.occurrences(of: ".desktopSwitchVerify") == 1)
        // …and its closure hands off to the body. The needle is
        // the call, located by what it cannot lose — the body's
        // own signature.
        #expect(
            source.occurrences(
                of: "self.verifyDesktopSwitch(to: target, verb: verb)"
            ) == 1
        )
    }
}
