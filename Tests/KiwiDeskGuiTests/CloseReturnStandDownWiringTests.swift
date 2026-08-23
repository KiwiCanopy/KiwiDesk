import Foundation
import Testing

/// The close-return stand-down's wiring (#913/#929/#935/#936) —
/// the hunks no behavior suite can red on.
///
/// The predicate's ARMS are behavior-tested
/// (`OwnDialogFocusTests`, through the injected `ownKeyWindow`
/// seam); what needs needles is that the two sites in
/// `KiwiCore+Events.swift` still ASK it. Why they cannot be
/// behavior tests: the raise sits behind `eventLoop.isListed`,
/// which calls live AX rather than the injected seam, so a
/// driven `handle(…)` never reaches the block for a fabricated
/// pid — and the trailing arm's skip is observable only through
/// `pendingZOrderRestore`, which a headless schedule consumes
/// (zero active animations run the restore immediately and the
/// empty element map drains it to nothing), so an assertion on
/// it passes with the guard deleted. Here, not beside the Core
/// suites, because `SourceScan` lives in this target and scans
/// both trees (AGENTS.md §1).
///
/// Known limits, stated rather than denied (the #635 practice):
/// anchored substrings over comment-stripped source. A clause
/// moved somewhere it never holds still matches. Deletion is
/// what these red on, which is the real failure mode — each is
/// one clause in a multi-line condition, and the diff that
/// drops one looks like a simplification. Before #935 each
/// clause carried a needle suite of its own
/// (`OwnDialogFocusWiringTests`, `HiddenAppRaiseWiringTests`);
/// the named predicate is what lets ONE needle pin the raise
/// site, so a new stand-down clause lands in the predicate, not
/// here.
@Suite("Close-return stand-down wiring (#935/#936)")
struct CloseReturnStandDownWiringTests {

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

    @Test("the raise site derives from the ONE predicate")
    func raiseSiteConsultsThePredicate() throws {
        let text = try eventsSource()
        let anchor =
            "eventLoop.closeReturnRaiseStandsDown(after: event)"
        let at = try #require(text.range(of: anchor))
        // The consult is guarded on the removal's focus loss:
        // both consumers need the answer only then, and the
        // production seam reads `NSApplication` — unguarded,
        // every move and focus event would pay it.
        let prefix = text[..<at.lowerBound].suffix(160)
        #expect(prefix.contains("focusLost"))
    }

    @Test("the close-return raise asks the stand-down")
    func raiseConditionAsksTheStandDown() throws {
        let text = try eventsSource()
        // A missing anchor means the raise's own condition
        // moved: re-anchor this needle rather than deleting it.
        let anchor = "effects.removedWindow?.focusLost == true"
        let at = try #require(text.range(of: anchor))
        // Scoped to the raise's condition, not the whole file:
        // the clause is only a stand-down where the raise is
        // decided.
        let condition = text[at.lowerBound...].prefix(240)
        #expect(condition.contains("!closeReturnRaiseStandsDown"))
    }

    @Test("a refused raise arms no track restore either (#936)")
    func trailingArmAsksTheStandDown() throws {
        let text = try eventsSource()
        // The trailing arm in handle(): the text immediately
        // before the schedule call must gate on the same
        // stand-down, or the restore's closing focus re-raise
        // undoes the refusal one settle later. (The focus-loss
        // half of the skip lives inside the shared local's own
        // definition — the needle above pins it.)
        let anchor = "scheduleTrackZOrderRestoreIfOverflowing()"
        let at = try #require(text.range(of: anchor))
        let guardText = text[..<at.lowerBound].suffix(200)
        #expect(
            guardText.contains("!closeReturnRaiseStandsDown")
        )
    }
}
