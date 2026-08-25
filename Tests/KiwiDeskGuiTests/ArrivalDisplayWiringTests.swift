import Foundation
import Testing

/// The production half of the cross-screen arrival rule (#1010),
/// which no behavior suite can red on.
///
/// `ArrivalScreenHomeTests` drives `StateCoordinator` directly:
/// it SETS `arrivalDisplay` and asserts what the fold does with
/// it. That is the whole pure half, and it stays green with the
/// app's own write deleted — proven, not assumed: replacing the
/// write with `state.arrivalDisplay = nil` left all 3907 tests
/// passing (guard-prover, 2026-08-25) while the shipped fix was
/// completely inert. "The fold reads the seam" and "the app
/// fills the seam" are two claims; this suite is the second
/// one's net.
///
/// It cannot be a behavior test at any altitude: the write reads
/// `NSScreen` through a static (`TilingEngine.screen`), so a
/// headless `handle(…)` resolves the host's real screens rather
/// than an injected seam — the #531 lesson, one level up.
///
/// Three things are pinned, and the ORDER is one of them: the
/// write must precede `state.apply(event)`, because the fold
/// consumes the value while folding that same event. A write
/// moved below the apply compiles, keeps every unit test green,
/// and re-homes the NEXT arrival by the previous one's screen.
///
/// Here rather than beside the Core suites because `SourceScan`
/// lives in this target and scans both trees (AGENTS.md §1).
///
/// Known limit, stated rather than denied (the #635 practice):
/// anchored substrings over comment-stripped source, scoped to
/// the arm under test rather than read against the whole file —
/// a needle satisfied by some other site is the `workflowStep`
/// lesson. Deletion and reordering are what these red on, which
/// is the real failure mode.
@Suite("Arrival display wiring (#1010)")
struct ArrivalDisplayWiringTests {
    private func eventsSource() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Events.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // Fail-shut on the scan itself: an empty read finds no
        // anchor, and the require says so out loud rather than
        // passing for having looked at nothing.
        try #require(!text.isEmpty)
        return text
    }

    /// The prologue arm that mirrors per-arrival inputs in,
    /// bounded by the statement that follows it in `handle`.
    private func createdArm(in text: String) throws -> Substring {
        let open = try #require(
            text.range(of: "if case .windowCreated(let window)")
        )
        let close = try #require(
            text.range(
                of: "let preEventFrame",
                range: open.upperBound..<text.endIndex
            )
        )
        return text[open.upperBound..<close.lowerBound]
    }

    @Test("the arrival's screen is resolved in the created arm")
    func theArmWritesTheDisplay() throws {
        let text = try eventsSource()
        let arm = try createdArm(in: text)
        #expect(arm.contains("state.arrivalDisplay ="))
        // Through the seam that owns the AX/AppKit y-flip, and
        // off the ARRIVING window's own frame — a comparison
        // spelled by hand here is silently wrong on a screen at
        // a negative y, which is the topology that needs it.
        #expect(arm.contains("TilingEngine.screen("))
        #expect(arm.contains("containing: window.frame"))
    }

    @Test("nothing else in the file writes the seam")
    func theWriteIsSingle() throws {
        let text = try eventsSource()
        #expect(text.occurrences(of: "state.arrivalDisplay =") == 1)
    }

    @Test("the write precedes the fold that consumes it")
    func theWritePrecedesTheApply() throws {
        let text = try eventsSource()
        let write = try #require(
            text.range(of: "state.arrivalDisplay =")
        )
        let apply = try #require(
            text.range(of: "let effects = state.apply(event)")
        )
        #expect(write.upperBound < apply.lowerBound)
    }
}
