import Foundation
import Testing

/// Three facts about the notification arms no behavior suite can
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
/// `EventLoop+WindowIDResolution`, whose fallback is the
/// `resolveWindowID` seam. A direct `AXHelper.windowID(` spelled
/// in an arm re-enters the round-trip with every route suite
/// green, because those suites inject the seam and never see a
/// call beside it — and so does a direct `resolveWindowID(`
/// call, which the route suites' log-line channel cannot see
/// either (guard-prover, 2026-09-22). The scan covers the WHOLE
/// `Events/` tree, and the two `allowed` maps are the one copy
/// of who may spell each — pinned by exact count so a site
/// added to one of those files reds too.
///
/// The commanded-focus stamp: `deliverFocusReport` drops a
/// report older than `lastCommandedFocus`, which only
/// `KiwiCore.focusWindow` writes — a deleted write leaves the
/// drop dead with `FocusArmDeliveryTests` green, since that
/// suite sets the stamp by hand.
@Suite("Notification arm needles (#1088)")
struct NotificationArmNeedleTests {
    private static let idRead = "AXHelper.windowID("
    private static let seamRead = "resolveWindowID("
    private static let titleRead = "AXHelper.title("

    /// Files under `Events/` that may spell the id read, with
    /// the count each may carry.
    private static let allowed: [String: Int] = [
        // The seam's production default.
        "EventLoop.swift": 1,
        // The create-time policy classification, ahead of any
        // registration the map could answer from.
        "EventLoop+WindowPolicy.swift": 2,
        // `appActivated`'s own focused-window read (#1322).
        "EventLoop+Apps.swift": 1,
    ]

    /// Files under `Events/` that may call the seam directly.
    private static let allowedSeam: [String: Int] = [
        // The resolver's one fallback (`askWindowID`).
        "EventLoop+WindowIDResolution.swift": 1,
        // The reconcile loop's per-listed-window read, routed
        // through the seam so `HiddenAppWindowTests` can state
        // what the app lists (the seam's own docstring).
        "EventLoop+Reconcile.swift": 1,
    ]

    private static func count(_ needle: String, in source: String)
        -> Int
    {
        source.components(separatedBy: needle).count - 1
    }

    private static func eventsFiles() throws -> [URL] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Events")
        return try FileManager.default
            .contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

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

    @Test("No file under Events spells the blocking reads uncensused")
    func eventsNeverSpellTheBlockingReads() throws {
        let files = try Self.eventsFiles()
        #expect(files.count >= 20, "scanned \(files.count) files")
        var seen: Set<String> = []
        var seenSeam: Set<String> = []
        for url in files {
            let name = url.lastPathComponent
            let source = try SourceScan.strippedSource(at: url)
            try #require(!source.isEmpty, "\(name) read empty")
            let ids = Self.count(Self.idRead, in: source)
            let expected = Self.allowed[name] ?? 0
            #expect(
                ids == expected,
                "\(name) spells \(Self.idRead) \(ids)×, allowed \(expected)"
            )
            if ids > 0 { seen.insert(name) }
            let seam = Self.count(Self.seamRead, in: source)
            let expectedSeam = Self.allowedSeam[name] ?? 0
            let seamNote: Comment =
                "\(name) calls the seam \(seam)×, allowed \(expectedSeam)"
            #expect(seam == expectedSeam, seamNote)
            if seam > 0 { seenSeam.insert(name) }
            #expect(
                !source.contains(Self.titleRead),
                "\(name) reads the title on the main actor"
            )
        }
        // Every allowed entry still exists, or a map is stale.
        #expect(seen == Set(Self.allowed.keys), "allowed map: \(seen)")
        #expect(
            seenSeam == Set(Self.allowedSeam.keys),
            "allowedSeam map: \(seenSeam)"
        )
    }

    @Test("The focus command stamps the loop")
    func focusCommandStampsTheLoop() throws {
        let body = try SourceScan.functionBody(
            of: "focusWindow",
            in: "KiwiCore+FocusRaise.swift",
            under: "Commands"
        )
        try #require(!body.isEmpty)
        #expect(body.contains("eventLoop.lastCommandedFocus = .now"))
        let delivery = try SourceScan.functionBody(
            of: "deliverFocusReport",
            in: "EventLoop+FocusReport.swift",
            under: "Events"
        )
        try #require(!delivery.isEmpty)
        #expect(delivery.contains("requested < commanded"))
    }
}
