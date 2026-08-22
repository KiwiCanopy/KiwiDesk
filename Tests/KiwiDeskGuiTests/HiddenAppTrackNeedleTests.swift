import Foundation
import Testing

/// The track refusal for a hidden app (#913) — a defence-in-depth
/// guard no behavior suite can reach.
///
/// Here, not in `HiddenAppWindowTests`, because `SourceScan` lives
/// in the GUI test target (AGENTS.md §1).
///
/// Why it cannot be a behavior test: `track`'s next read is
/// `AXHelper.role(of:)`, which is a direct AX call and not an
/// injected seam, so any fabricated element returns a nil role
/// and exits one line later either way. Reaching it would require
/// a real `kAXWindowRole` element (a live AX-trusted window),
/// which tests.md forbids.
///
/// A presence and position scan: pins that `!appIsHidden(pid)`
/// is checked inside the first ~200 characters of `track`'s body
/// and strictly before the first `AXHelper.role` read. Deletion
/// or moving the check after AX calls reds.
@Suite("Hidden-app track needle (#913)")
struct HiddenAppTrackNeedleTests {
    @Test("track refuses a hidden app before querying AX role")
    func trackRefusesHiddenAppBeforeAXRole() throws {
        let body = try SourceScan.functionBody(
            of: "track",
            in: "EventLoop+Tracking.swift",
            under: "Events"
        )
        try #require(!body.isEmpty)
        let hideIndex = try #require(
            body.range(of: "!appIsHidden(pid)")
        )
        let roleIndex = try #require(
            body.range(of: "AXHelper.role(of: element)")
        )
        #expect(hideIndex.lowerBound < roleIndex.lowerBound)
        #expect(
            body.distance(
                from: body.startIndex,
                to: hideIndex.lowerBound
            ) < 200
        )
    }
}
