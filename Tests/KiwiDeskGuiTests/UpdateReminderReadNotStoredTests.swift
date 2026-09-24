import Foundation
import Testing

/// The one-home obligation no behavior test can hold: a cached
/// copy kept in sync by the nudge passes every render assertion,
/// so the controller's READ is pinned by spelling — a computed
/// property over the updater, and no stored copy anywhere in the
/// file (gui.md).
@Suite("The pending fact is read, never stored (#1013)")
struct UpdateReminderReadNotStoredTests {
    @Test("the controller reads the updater's fact at render")
    func controllerReadsNotStores() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/StatusItemController.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        try #require(!source.isEmpty)
        #expect(
            source.contains(
                "var updatePending: Bool { updater.updatePending }"
            )
        )
        #expect(!source.contains("updatePending ="))
        #expect(!source.contains("var updatePending = "))
        // A copy under ANOTHER name would be written from the
        // nudge: the closure carries the render and nothing else.
        let start = try #require(
            source.range(of: "onUpdatePendingChanged = {")
        )
        let close = try #require(
            source[start.upperBound...].range(of: "}")
        )
        let nudge = source[start.upperBound..<close.lowerBound]
        #expect(nudge.contains("render()"))
        #expect(!nudge.contains("="))
        // "What's new" waiting (#1542) is the second fact under the
        // same rule: read from the coordinator, its nudge a render.
        #expect(
            source.contains(
                "var whatsNewWaiting: String? { "
                    + "updater.whatsNew?.waiting?.version }"
            )
        )
        // An assignment, never a comparison: `==` reads the fact.
        let updates = SourceScan.stripComments(
            try String(
                contentsOf: file.deletingLastPathComponent()
                    .appendingPathComponent(
                        "StatusItemController+Updates.swift"
                    ),
                encoding: .utf8
            )
        )
        for text in [source, updates] {
            #expect(
                text.range(
                    of: #"whatsNewWaiting\s*=(?!=)"#,
                    options: .regularExpression
                ) == nil
            )
        }
        let waitStart = try #require(
            source.range(of: "onWaitingChanged = {")
        )
        let waitClose = try #require(
            source[waitStart.upperBound...].range(of: "}")
        )
        let waitNudge = source[waitStart.upperBound..<waitClose.lowerBound]
        #expect(waitNudge.contains("render()"))
        #expect(!waitNudge.contains("="))
    }
}
