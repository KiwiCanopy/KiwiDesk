import Foundation
import Testing

/// `reset_layout_sizing`'s z-order wiring (#764, #153): the verb
/// retiles through the dispatcher's trailer, so its track
/// restore is RECORDED for that retile through
/// `requestZOrderRestoreAfterDispatch`, gated on the one
/// `activeTrackOverflows` predicate — never armed on the spot,
/// which runs the restore off the pre-reset frames. The
/// BEHAVIOUR is `ResetLayoutSizingZOrderTests`' (the restore
/// still pending after the dispatcher's retile animates); what
/// needs needles is the negative half — an immediate arm ADDED
/// beside the recorded one drains nothing that suite reads — and
/// that the two arms share one predicate. Here, not beside the
/// Core suites, because `SourceScan` lives in this target
/// (AGENTS.md §1).
@Suite("reset_layout_sizing z-order wiring (#764)")
struct ResetLayoutSizingWiringTests {
    private func body() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Commands/"
                    + "KiwiCore+ResetLayoutSizing.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        try #require(!text.isEmpty)
        return text
    }

    @Test("the restore is recorded for the dispatcher, gated on overflow")
    func restoreIsDeferredAndGated() throws {
        let text = try body()
        #expect(
            text.contains(
                "ifactiveTrackOverflows{requestZOrderRestoreAfterDispatch()}"
            )
        )
        #expect(
            text.components(separatedBy: "requestZOrderRestoreAfterDispatch(")
                .count == 2
        )
        for arm in [
            "scheduleZOrderRestore(",
            "scheduleTrackZOrderRestoreIfOverflowing(",
        ] {
            #expect(
                !text.contains(arm),
                Comment(rawValue: "the reset arms on the spot: \(arm)")
            )
        }
    }

    /// The one gate: the immediate arm reads the same predicate,
    /// so the two cannot disagree about what a track pile is.
    @Test("the immediate track arm reads the same predicate")
    func immediateArmSharesThePredicate() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Commands/KiwiCore+ZOrder.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        try #require(!text.isEmpty)
        #expect(
            text.contains(
                "funcscheduleTrackZOrderRestoreIfOverflowing(){"
                    + "guardactiveTrackOverflowselse{return}"
                    + "scheduleZOrderRestore()}"
            )
        )
        #expect(
            text.components(separatedBy: "varactiveTrackOverflows:Bool{")
                .count == 2
        )
    }
}
