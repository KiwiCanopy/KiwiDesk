import Foundation
import Testing

/// The hide drop's stand-down at the close-return raise (#913)
/// — the hunk no behavior suite can red on.
///
/// Here, not beside `HiddenAppRaiseTests` in the Core target,
/// because `SourceScan` lives in this target and scans both
/// trees (AGENTS.md §1). That suite pins the predicate itself;
/// this pins that the raise site still asks it.
///
/// Why neither can be a behavior test: the raise sits behind
/// `eventLoop.isListed`, which calls live AX rather than the
/// injected seam, so a driven `handle(…)` never reaches the
/// block for a fabricated pid — an assertion there would pass
/// with the stand-down deleted.
///
/// Known limits, stated rather than denied (the #635 practice):
/// an anchored substring over comment-stripped source. A
/// condition moved somewhere it never holds still matches.
/// Deletion is what it reds on, which is this line's real
/// failure mode — it is one clause in a multi-line `if`, and
/// the diff that drops it looks like a simplification.
@Suite("Hidden-app raise wiring (#913)")
struct HiddenAppRaiseWiringTests {
    @Test("the close-return raise stands down on a hide")
    func raiseSiteConsultsTheHidePredicate() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Events.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // Fail-shut on the scan itself: an empty read finds no
        // anchor, and the require below says so out loud rather
        // than passing for having looked at nothing.
        try #require(!text.isEmpty)
        let anchor = "effects.removedWindow?.focusLost == true"
        // A missing anchor means the raise's own condition
        // moved: re-anchor this needle rather than deleting it.
        let at = try #require(text.range(of: anchor))
        // Scoped to the raise's condition, not the whole file:
        // the clause is only a stand-down where the raise is
        // decided, and a stray mention elsewhere is not it.
        let condition = text[at.lowerBound...].prefix(240)
        #expect(condition.contains("!event.isHideDrop"))
    }
}
