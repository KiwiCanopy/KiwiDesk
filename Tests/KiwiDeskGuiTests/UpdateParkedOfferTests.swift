import AppKit
import Sparkle
import Testing

@testable import KiwiDesk

/// A scheduled offer parked behind the mark is answered Later when
/// the user asks, and their check starts at the cycle's end, so the
/// feed is read afresh rather than the parked offer re-shown
/// (#3139). Driven through the production `UpdatePromptDriver`;
/// nothing is put on screen. Main-actor spend: one source read.
@MainActor
@Suite("Parked update offer re-checks (#3139)", .serialized)
struct UpdateParkedOfferTests {
    private final class Log {
        var presented = 0
        var checks = 0
        var replies: [SPUUserUpdateChoice] = []
    }

    private func driver() -> (UpdatePromptDriver, Log) {
        let log = Log()
        let driver = UpdatePromptDriver(
            hostBundle: Bundle.main,
            delegate: UpdatePromptPolicy()
        )
        driver.presents = { _ in log.presented += 1 }
        driver.startCheck = { log.checks += 1 }
        driver.seenRecord = WhatsNewRecord(
            makeScratchDefaults().defaults
        )
        return (driver, log)
    }

    private static func item(_ version: String) throws -> SUAppcastItem {
        try #require(
            SUAppcastItem(
                dictionary: [
                    "sparkle:version": version,
                    "enclosure": [
                        "url": "https://example.invalid/K.zip",
                        "length": "1",
                    ],
                ]
            )
        )
    }

    private func park(
        _ driver: UpdatePromptDriver,
        _ log: Log,
        stage: SPUUserUpdateStage = .notDownloaded
    ) throws {
        driver.showUpdateFound(
            try Self.item("9999.1.0"),
            userInitiated: false,
            stage: stage
        ) { log.replies.append($0) }
        #expect(driver.prompts.updatePending)
        #expect(log.presented == 0)
    }

    @Test("a parked offer is answered Later, then checked afresh")
    func parkedOfferRechecks() throws {
        let (driver, log) = driver()
        try park(driver, log)
        #expect(driver.dropParkedOffer())
        #expect(log.replies == [.dismiss])
        #expect(driver.window == nil)
        #expect(log.presented == 0)
        // Sparkle's session ends; only then may the check start.
        driver.dismissUpdateInstallation()
        #expect(log.checks == 0)
        driver.updateCycleFinished()
        #expect(log.checks == 1)
        // One check owed, once.
        driver.updateCycleFinished()
        #expect(log.checks == 1)
    }

    /// The fresh check re-finding the same build is a new offer
    /// the user sees, never Try Again's install-on-refind.
    @Test("the fresh check offers, never installs")
    func freshCheckOffers() throws {
        let (driver, log) = driver()
        try park(driver, log)
        #expect(driver.dropParkedOffer())
        driver.updateCycleFinished()
        driver.showUserInitiatedUpdateCheck {}
        var again: [SPUUserUpdateChoice] = []
        driver.showUpdateFound(
            try Self.item("9999.1.0"),
            userInitiated: true,
            stage: .notDownloaded
        ) { again.append($0) }
        #expect(again.isEmpty)
        #expect(driver.window?.session.phase == .found)
        #expect(!driver.prompts.updatePending)
    }

    /// Sparkle resumes a downloaded or installing update without
    /// a fetch, so dropping one would re-offer the same build.
    @Test(
        "a downloaded or installing offer is not dropped",
        arguments: [SPUUserUpdateStage.downloaded, .installing]
    )
    func heldStagesAreKept(stage: SPUUserUpdateStage) throws {
        let (driver, log) = driver()
        try park(driver, log, stage: stage)
        #expect(!driver.dropParkedOffer())
        #expect(log.replies.isEmpty)
        #expect(driver.window != nil)
        driver.updateCycleFinished()
        #expect(log.checks == 0)
    }

    /// An offer the user has seen just comes forward.
    @Test("a shown offer is not dropped")
    func shownOfferIsKept() throws {
        let (driver, log) = driver()
        try park(driver, log)
        driver.showUpdateInFocus()
        #expect(!driver.prompts.updatePending)
        #expect(!driver.dropParkedOffer())
        #expect(log.replies.isEmpty)
    }

    /// An offer past its Install is under way, not parked: its
    /// Later would cancel the download.
    @Test("an offer under way is not dropped")
    func underWayIsKept() throws {
        let (driver, log) = driver()
        try park(driver, log)
        let session = try #require(driver.window?.session)
        session.install()
        #expect(!driver.dropParkedOffer())
        #expect(log.replies == [.install])
        driver.updateCycleFinished()
        #expect(log.checks == 0)
    }

    @Test("no open offer, nothing dropped")
    func nothingOpen() {
        let (driver, log) = driver()
        #expect(!driver.dropParkedOffer())
        driver.updateCycleFinished()
        #expect(log.checks == 0)
    }

    /// The live updater asks the drop before the bring-forward,
    /// which would clear the pending fact the drop reads.
    @Test("the live check drops a parked offer first")
    func liveCheckDropsFirst() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Updates/AppUpdater.swift"
                )
        )
        let after = try #require(
            source.components(separatedBy: "func checkForUpdates() {")
                .dropFirst().first
        )
        let body = try #require(
            after.components(separatedBy: "func startOwnCheck()").first
        )
        let drop = try #require(
            body.range(of: "if driver.dropParkedOffer() { return }")
        )
        let focus = try #require(
            body.range(of: "if driver.focusOpenWindow() { return }")
        )
        #expect(drop.upperBound < focus.lowerBound)
    }
}
