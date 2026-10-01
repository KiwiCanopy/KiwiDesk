import AppKit
import Sparkle
import Testing

@testable import KiwiDesk

/// "You're up to date" is the update window's answer (#1849): the
/// reason Sparkle gives decides who answers, the window opens on
/// the running version's notes with the list fetched first, and
/// its Done is Sparkle's acknowledgement. Nothing goes on screen —
/// the present step is recorded.
@MainActor
@Suite("Update window: up to date (#1849)", .serialized)
struct UpdateUpToDateTests {
    private final class Log {
        var shown: [UpToDateWindowController] = []
        var sparkle = 0
        var acknowledged = 0
    }

    private func driver(
        next: NextOnMyList? = nil
    ) -> (UpdatePromptDriver, Log) {
        let log = Log()
        let driver = UpdatePromptDriver(
            hostBundle: Bundle.main,
            delegate: UpdatePromptPolicy()
        )
        driver.presents = { _ in }
        driver.presentsUpToDate = { log.shown.append($0) }
        driver.sparkleNotFound = { _, _ in log.sparkle += 1 }
        driver.fetchNext = { next }
        return (driver, log)
    }

    private static func notFound(
        _ reason: SPUNoUpdateFoundReason?
    ) -> NSError {
        var info: [String: Any] = [:]
        if let reason {
            info[SPUNoUpdateFoundReasonKey] = NSNumber(
                value: reason.rawValue
            )
        }
        return NSError(
            domain: SUSparkleErrorDomain,
            code: Int(SUError.noUpdateError.rawValue),
            userInfo: info
        )
    }

    private func settle(_ driver: UpdatePromptDriver) async {
        await driver.upToDateFetch?.value
    }

    @Test("on the newest version the window answers, list first")
    func latestOpensTheWindow() async throws {
        let list = NextOnMyList(asOf: Date(), items: ["One"])
        let (driver, log) = driver(next: list)
        driver.showUpdateNotFoundWithError(
            Self.notFound(.onLatestVersion)
        ) { log.acknowledged += 1 }
        await settle(driver)
        let shown = try #require(log.shown.first)
        #expect(log.shown.count == 1)
        #expect(log.sparkle == 0)
        #expect(shown.next == list)
        #expect(driver.upToDate === shown)
    }

    @Test("newer than the feed's newest is up to date too")
    func newerThanLatestOpensTheWindow() async {
        let (driver, log) = driver()
        driver.showUpdateNotFoundWithError(
            Self.notFound(.onNewerThanLatestVersion)
        ) {}
        await settle(driver)
        #expect(log.shown.count == 1)
        #expect(log.sparkle == 0)
    }

    @Test("every other reason keeps Sparkle's explanation")
    func otherReasonsStaySparkles() async {
        for reason: SPUNoUpdateFoundReason? in [
            .systemIsTooOld, .systemIsTooNew, .unknown, nil,
        ] {
            let (driver, log) = driver()
            driver.showUpdateNotFoundWithError(Self.notFound(reason)) {}
            await settle(driver)
            #expect(log.shown.isEmpty, "\(String(describing: reason))")
            #expect(log.sparkle == 1, "\(String(describing: reason))")
        }
    }

    @Test("a list past its age is left out")
    func staleListIsLeftOut() async {
        let old = Date().addingTimeInterval(
            -(NextOnMyList.maxAge + 86_400)
        )
        let (driver, log) = driver(
            next: NextOnMyList(asOf: old, items: ["One"])
        )
        driver.showUpdateNotFoundWithError(
            Self.notFound(.onLatestVersion)
        ) {}
        await settle(driver)
        #expect(log.shown.first?.next == nil)
    }

    @Test("Done answers Sparkle once and ends the answer")
    func doneAcknowledges() async throws {
        let (driver, log) = driver()
        driver.showUpdateNotFoundWithError(
            Self.notFound(.onLatestVersion)
        ) { log.acknowledged += 1 }
        await settle(driver)
        let window = try #require(log.shown.first).makeWindow()
        _ = window.delegate?.windowShouldClose?(window)
        #expect(log.acknowledged == 1)
        #expect(driver.upToDate == nil)
    }

    /// Home read "Checking…" with its button greyed while the
    /// answer waited on Done (device, 2026-10-01): the answer
    /// says so at once, and a second check brings it back.
    @Test("the answer reports itself and comes back in focus")
    func answerReportsAndRefocuses() async {
        let (driver, log) = driver()
        var reported = 0
        driver.onUpToDate = { reported += 1 }
        driver.showUpdateNotFoundWithError(
            Self.notFound(.onLatestVersion)
        ) {}
        await settle(driver)
        #expect(reported == 1)
        driver.showUpdateInFocus()
        #expect(log.shown.count == 2)
        #expect(log.shown.last === driver.upToDate)
    }

    /// The click that brings an open answer back must not narrate
    /// a new check: Home read "Checking…" under the open window
    /// (device, 2026-10-01). `canCheckForUpdates` stays true
    /// through a session, so the gate asks `sessionInProgress`.
    @Test("a check during an open session narrates nothing")
    func openSessionNarratesNoCheck() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath).appendingPathComponent(
                "Sources/KiwiDesk/Updates/AppUpdater.swift"
            )
        )
        #expect(
            source.contains(
                "if updater.canCheckForUpdates, !updater.sessionInProgress {"
                    + "\n            updates.set(updates.state.onOwnCheck)"
            )
        )
    }
}
