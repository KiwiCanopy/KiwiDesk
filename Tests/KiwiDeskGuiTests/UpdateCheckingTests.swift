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
        driver.presents = {
            if case .checking = $0 { log.checking += 1 }
        }
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

    /// What the driver put up and took down, in order.
    private static func events(_ driver: UpdatePromptDriver) -> Box {
        let box = Box()
        driver.presents = { box.log.append("up " + Self.name($0)) }
        driver.closes = { box.log.append("down " + Self.name($0)) }
        return box
    }

    private final class Box { var log: [String] = [] }

    private static func name(_ slot: UpdateWindowSlot) -> String {
        switch slot {
        case .checking: return "checking"
        case .offer: return "offer"
        case .upToDate: return "upToDate"
        }
    }

    /// A closing key window hands focus back to the window under
    /// it and the answer is reverted as a z-order echo (device,
    /// 2026-10-01): the answer goes up before the check comes down.
    @Test("the answer is up before the checking window goes")
    func answerIsUpFirst() async {
        let (driver, log) = driver()
        let box = Self.events(driver)
        check(driver, log)
        driver.showUpdateNotFoundWithError(Self.notFound(.onLatestVersion)) {}
        await driver.upToDateFetch?.value
        #expect(box.log == ["up checking", "up upToDate", "down checking"])
    }

    @Test("a found offer is up before the checking window goes")
    func offerIsUpFirst() throws {
        let (driver, log) = driver()
        let box = Self.events(driver)
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
        #expect(box.log == ["up checking", "up offer", "down checking"])
    }

    /// Sparkle's cancellation does nothing once the appcast loaded,
    /// so a Cancel while the list is fetched ends the pending
    /// answer itself (review, 2026-10-01): no answer, and Sparkle
    /// acknowledged exactly once.
    @Test("Cancel during the list fetch ends the answer")
    func cancelDuringFetchEndsTheAnswer() async throws {
        let (driver, log) = driver()
        var acknowledged = 0
        var answers = 0
        driver.presents = { if case .upToDate = $0 { answers += 1 } }
        driver.fetchNext = {
            try? await Task.sleep(for: .seconds(30))
            return nil
        }
        check(driver, log)
        driver.showUpdateNotFoundWithError(Self.notFound(.onLatestVersion)) {
            acknowledged += 1
        }
        let fetch = try #require(driver.upToDateFetch)
        let window = try #require(driver.checking).makeWindow()
        _ = window.delegate?.windowShouldClose?(window)
        await fetch.value
        #expect(answers == 0)
        #expect(acknowledged == 1)
        #expect(log.cancelled == 0)
        #expect(driver.current == nil)
    }

    @Test("the session's end drops a pending answer unanswered")
    func dismissDropsThePendingAnswer() async throws {
        let (driver, log) = driver()
        var acknowledged = 0
        driver.fetchNext = {
            try? await Task.sleep(for: .seconds(30))
            return nil
        }
        check(driver, log)
        driver.showUpdateNotFoundWithError(Self.notFound(.onLatestVersion)) {
            acknowledged += 1
        }
        let fetch = try #require(driver.upToDateFetch)
        driver.dismissUpdateInstallation()
        await fetch.value
        #expect(driver.current == nil)
        #expect(driver.upToDate == nil)
        #expect(acknowledged == 0)
    }
}
