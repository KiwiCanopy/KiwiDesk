import AppKit
import Sparkle
import Testing

@testable import KiwiDesk

/// A user's check shows "Checking for updates…" in the update
/// window rather than Sparkle's panel (#1849), and every answer —
/// up to date, Sparkle's own wording, an error, the session's end —
/// takes it down. Nothing goes on screen.
@MainActor
@Suite("Update window: checking (#1849)", .serialized)
struct UpdateCheckingTests {
    private final class Log {
        var checking = 0
        var cancelled = 0
    }

    private func driver() -> (UpdatePromptDriver, Log) {
        let log = Log()
        let driver = UpdatePromptDriver(
            hostBundle: Bundle.main,
            delegate: UpdatePromptPolicy()
        )
        driver.presents = { _ in }
        driver.presentsUpToDate = { _ in }
        driver.presentsChecking = { _ in log.checking += 1 }
        driver.sparkleNotFound = { _, _ in }
        driver.sparkleError = { _, _ in }
        driver.fetchNext = { nil }
        return (driver, log)
    }

    private func check(_ driver: UpdatePromptDriver, _ log: Log) {
        driver.showUserInitiatedUpdateCheck { log.cancelled += 1 }
    }

    private static func notFound(_ reason: SPUNoUpdateFoundReason) -> NSError {
        NSError(
            domain: SUSparkleErrorDomain,
            code: Int(SUError.noUpdateError.rawValue),
            userInfo: [
                SPUNoUpdateFoundReasonKey: NSNumber(value: reason.rawValue)
            ]
        )
    }

    @Test("a user's check opens the checking window")
    func checkOpensIt() {
        let (driver, log) = driver()
        check(driver, log)
        #expect(log.checking == 1)
        #expect(driver.checking != nil)
    }

    @Test("up to date replaces it")
    func upToDateClosesIt() async {
        let (driver, log) = driver()
        check(driver, log)
        driver.showUpdateNotFoundWithError(Self.notFound(.onLatestVersion)) {}
        // Still up while the list is fetched.
        #expect(driver.checking != nil)
        await driver.upToDateFetch?.value
        #expect(driver.checking == nil)
        #expect(driver.upToDate != nil)
    }

    @Test("Sparkle's own no-update wording and an error close it")
    func sparkleAnswersCloseIt() {
        for answer in 0..<2 {
            let (driver, log) = driver()
            check(driver, log)
            if answer == 0 {
                driver.showUpdateNotFoundWithError(
                    Self.notFound(.systemIsTooOld)
                ) {}
            } else {
                driver.showUpdaterError(
                    NSError(domain: "test", code: 1)
                ) {}
            }
            #expect(driver.checking == nil, "answer \(answer)")
        }
    }

    @Test("the session's end closes it")
    func dismissClosesIt() {
        let (driver, log) = driver()
        check(driver, log)
        driver.dismissUpdateInstallation()
        #expect(driver.checking == nil)
    }

    @Test("Cancel cancels Sparkle's check")
    func cancelCancels() throws {
        let (driver, log) = driver()
        check(driver, log)
        let window = try #require(driver.checking).makeWindow()
        _ = window.delegate?.windowShouldClose?(window)
        #expect(log.cancelled == 1)
    }

    /// A closing key window hands focus back to the window under
    /// it and the answer is reverted as a z-order echo (device,
    /// 2026-10-01): the answer must be put up first.
    @Test("the answer is up before the checking window goes")
    func answerIsUpFirst() async {
        let (driver, log) = driver()
        var checkingAtAnswer: Bool?
        driver.presentsUpToDate = { [weak driver] _ in
            checkingAtAnswer = driver?.checking != nil
        }
        check(driver, log)
        driver.showUpdateNotFoundWithError(Self.notFound(.onLatestVersion)) {}
        await driver.upToDateFetch?.value
        #expect(checkingAtAnswer == true)
        #expect(driver.checking == nil)
    }

    @Test("a found offer is up before the checking window goes")
    func offerIsUpFirst() throws {
        let (driver, log) = driver()
        var checkingAtOffer: Bool?
        driver.presents = { [weak driver] _ in
            checkingAtOffer = driver?.checking != nil
        }
        check(driver, log)
        let item = try #require(
            SUAppcastItem(
                dictionary: [
                    "sparkle:version": "9999.1.0",
                    "enclosure": [
                        "url": "https://example.invalid/K.zip",
                        "length": "1",
                    ],
                ]
            )
        )
        driver.showUpdateFound(
            item,
            userInitiated: true,
            stage: .notDownloaded
        ) { _ in }
        #expect(checkingAtOffer == true)
        #expect(driver.checking == nil)
    }
}
