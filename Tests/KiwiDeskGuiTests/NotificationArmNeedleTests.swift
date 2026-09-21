import Foundation
import Testing

/// Two facts about the notification arms no behavior suite can
/// reach (#1088). Here because `SourceScan` lives in the GUI
/// test target (AGENTS.md §1).
///
/// The #160 float recheck: its next read is
/// `FloatDetection.shouldFloat(element:…)`, a direct AX call
/// and not an injected seam, so a fabricated element answers
/// it either way. A presence-and-position scan pins that the
/// recheck runs in the title arm's DELIVERY, after the read,
/// and not at receipt — moved back to receipt it would run on
/// the main actor for every title notification of a
/// titled-rule app, which is the storm this route exists to
/// take off that thread.
///
/// The blocking id read: every arm resolves through
/// `windowID(of:pid:arm:)` / `trackedMatch`, and the seam it
/// falls through to is `resolveWindowID`. A direct
/// `AXHelper.windowID(` spelled in an arm file re-enters the
/// round-trip with every route suite green, because those
/// suites inject the seam and never see a call beside it.
@Suite("Notification arm needles (#1088)")
struct NotificationArmNeedleTests {
    private static let armFiles = [
        "EventLoop+Notifications.swift",
        "EventLoop+FocusReport.swift",
        "EventLoop+TitleReport.swift",
        "EventLoop+WindowIDResolution.swift",
    ]

    @Test("The #160 recheck runs at the title arm's delivery")
    func floatRecheckRunsAtDelivery() throws {
        let delivery = try SourceScan.functionBody(
            of: "deliverTitleReport",
            in: "EventLoop+TitleReport.swift",
            under: "Events"
        )
        try #require(!delivery.isEmpty)
        let emit = try #require(
            delivery.range(of: ".windowTitleChanged(")
        )
        let gate = try #require(delivery.range(of: "hasTitleRule("))
        let recheck = try #require(delivery.range(of: "recheckFloat("))
        #expect(emit.lowerBound < gate.lowerBound)
        #expect(gate.lowerBound < recheck.lowerBound)
        let receipt = try SourceScan.functionBody(
            of: "handleTitleChanged",
            in: "EventLoop+TitleReport.swift",
            under: "Events"
        )
        try #require(!receipt.isEmpty)
        #expect(!receipt.contains("recheckFloat("))
        #expect(receipt.contains("requestTitle("))
    }

    @Test("No arm file spells the blocking id read")
    func armsNeverSpellTheBlockingRead() throws {
        for file in Self.armFiles {
            let url = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDeskCore/Events")
                .appendingPathComponent(file)
            let source = try SourceScan.strippedSource(at: url)
            try #require(!source.isEmpty, "\(file) read empty")
            #expect(
                !source.contains("AXHelper.windowID("),
                "\(file) asks the app directly"
            )
            #expect(
                !source.contains("AXHelper.title("),
                "\(file) reads the title on the main actor"
            )
        }
    }
}
