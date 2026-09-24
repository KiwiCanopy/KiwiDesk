import AppKit
import Sparkle
import Testing

@testable import KiwiDesk

/// The driver hands a found update to KiwiDesk's own window and
/// every phase after it (#1542), through the production
/// `UpdatePromptDriver`: a scheduled offer waits behind the mark
/// (#1013), a user's own check comes forward (#1011). Nothing is
/// put on screen — the present step is recorded.
@MainActor
@Suite("Update window routing (#1542)", .serialized)
struct UpdateWindowRoutingTests {
    private final class Log {
        var presented = 0
        var replies: [SPUUserUpdateChoice] = []
    }

    private func driver() -> (UpdatePromptDriver, Log) {
        let log = Log()
        let driver = UpdatePromptDriver(
            hostBundle: Bundle.main,
            delegate: UpdatePromptPolicy()
        )
        driver.presents = { _ in log.presented += 1 }
        return (driver, log)
    }

    private static func notes(_ item: String) -> String {
        """
        {"format":1,"summary":"S.","sections":\
        [{"type":"new","title":"New","items":["\(item)"]}]}
        """
    }

    /// Built as Sparkle's appcast reader builds one: a dictionary
    /// keyed by element name, the notes under the qualified one.
    private static func item(_ version: String) throws -> SUAppcastItem {
        try #require(
            SUAppcastItem(
                dictionary: [
                    "sparkle:version": version,
                    "enclosure": [
                        "url": "https://example.invalid/K.zip",
                        "length": "1",
                    ],
                    ReleaseNotes.element: notes("in \(version)"),
                ]
            )
        )
    }

    @Test("a scheduled offer waits behind the mark")
    func scheduledWaits() throws {
        let (driver, log) = driver()
        driver.showUpdateFound(
            try Self.item("9999.1.0"),
            userInitiated: false
        ) { log.replies.append($0) }
        #expect(driver.window != nil)
        #expect(log.presented == 0)
        #expect(driver.prompts.updatePending)
        // The row's check brings it forward and clears the mark.
        driver.showUpdateInFocus()
        #expect(log.presented == 1)
        #expect(!driver.prompts.updatePending)
    }

    @Test("a user's own check comes forward")
    func userCheckPresents() throws {
        let (driver, log) = driver()
        driver.showUpdateFound(
            try Self.item("9999.1.0"),
            userInitiated: true
        ) { log.replies.append($0) }
        #expect(log.presented == 1)
        #expect(!driver.prompts.updatePending)
    }

    /// The offer merges every loaded item newer than the running
    /// version, so a skipped release's entries arrive labelled.
    @Test("the offer merges the loaded appcast")
    func offerMergesTheAppcast() throws {
        let (driver, log) = driver()
        driver.loadedItems = [
            try Self.item("9999.0.5"), try Self.item("9999.1.0"),
        ]
        driver.showUpdateFound(
            try Self.item("9999.1.0"),
            userInitiated: true
        ) { log.replies.append($0) }
        let digest = try #require(driver.window?.offer.digest)
        #expect(digest.versions == ["9999.1.0", "9999.0.5"])
        #expect(
            digest.groups.first?.entries.map(\.text)
                == ["in 9999.1.0", "in 9999.0.5"]
        )
    }

    /// Each phase after the offer lands in the window's session,
    /// and Sparkle's teardown closes the window.
    @Test("the phases route to the window, and dismiss closes it")
    func phasesRoute() throws {
        let (driver, log) = driver()
        driver.showUpdateFound(
            try Self.item("9999.1.0"),
            userInitiated: true
        ) { log.replies.append($0) }
        let session = try #require(driver.window?.session)
        session.install()
        #expect(log.replies == [.install])
        driver.showDownloadInitiated {}
        driver.showDownloadDidReceiveExpectedContentLength(10)
        driver.showDownloadDidReceiveData(ofLength: 4)
        #expect(session.phase == .downloading(received: 4, expected: 10))
        driver.showDownloadDidStartExtractingUpdate()
        #expect(session.phase == .preparing)
        driver.showInstallingUpdate(
            withApplicationTerminated: true,
            retryTerminatingApplication: {}
        )
        #expect(session.phase == .installing)
        driver.dismissUpdateInstallation()
        #expect(driver.window == nil)
    }

    /// Titled, not tiled, not miniaturizable, closable — and the
    /// close is Later, answered by the session rather than AppKit.
    @Test("the window's shape, and its close means Later")
    func windowShape() throws {
        let (driver, log) = driver()
        driver.showUpdateFound(
            try Self.item("9999.1.0"),
            userInitiated: false
        ) { log.replies.append($0) }
        let controller = try #require(driver.window)
        let window = controller.makeWindow()
        #expect(window.styleMask.contains(.titled))
        #expect(window.styleMask.contains(.closable))
        #expect(!window.styleMask.contains(.miniaturizable))
        #expect(!window.styleMask.contains(.resizable))
        #expect(window.identifier == nil)
        #expect(!controller.windowShouldClose(window))
        #expect(log.replies == [.dismiss])
        #expect(driver.window == nil)
    }

    /// A download failure holds Sparkle's acknowledgement in the
    /// window rather than raising Sparkle's alert.
    @Test("a failure after the offer is the window's")
    func failureIsTheWindows() throws {
        let (driver, log) = driver()
        driver.showUpdateFound(
            try Self.item("9999.1.0"),
            userInitiated: true
        ) { log.replies.append($0) }
        let session = try #require(driver.window?.session)
        session.install()
        var acknowledged = 0
        driver.showUpdaterError(
            NSError(domain: NSURLErrorDomain, code: -1)
        ) { acknowledged += 1 }
        #expect(session.phase == .failed(.download))
        #expect(acknowledged == 0)
        session.later()
        #expect(acknowledged == 1)
    }
}
