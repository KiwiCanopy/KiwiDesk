import AppKit
import Foundation
import Sparkle
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// How "Next on my list" reaches the What's new window (#1813):
/// fetched beside the feed on a launch, carried across the
/// relaunch from the offer's own fetch, and judged by its age when
/// the window is built. Nothing reaches the network.
@MainActor
@Suite("Next on my list reaches What's new (#1813)", .serialized)
struct NextOnMyListWiringTests {
    private final class Asked {
        var urls: [URL] = []
    }

    private static let list = NextOnMyList(
        asOf: Date(timeIntervalSince1970: 1_790_000_000),
        items: ["One", "Two"]
    )

    private static let day: TimeInterval = 86_400

    @Test("a launch fetches it beside the feed and hands it on")
    func launchHandsItOn() async throws {
        let (coordinator, _, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        let asked = Asked()
        coordinator.fetchNext = {
            asked.urls.append($0)
            return Self.list
        }
        coordinator.now = { Self.list.asOf + Self.day }
        var shown: WhatsNewWindowController?
        coordinator.presents = { shown = $0 }
        await coordinator.launched(opensWindow: true, existingUser: true)
        #expect(
            asked.urls.map(\.absoluteString) == [
                "https://example.invalid/appcast.xml"
            ]
        )
        #expect(shown?.next == Self.list)
    }

    @Test("a list past its age opens the window without it")
    func staleListIsLeftOut() async throws {
        let (coordinator, _, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        coordinator.fetchNext = { _ in Self.list }
        coordinator.now = { Self.list.asOf + 61 * Self.day }
        var shown: WhatsNewWindowController?
        coordinator.presents = { shown = $0 }
        await coordinator.launched(opensWindow: true, existingUser: true)
        #expect(shown != nil)
        #expect(shown?.next == nil)
    }

    @Test("the relaunch opens with the carried list, without a fetch")
    func relaunchCarriesIt() throws {
        let (coordinator, record, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: nil
        )
        let asked = Asked()
        coordinator.fetchNext = {
            asked.urls.append($0)
            return nil
        }
        coordinator.now = { Self.list.asOf }
        var relaunch = WhatsNewRecord.Relaunch(
            version: "9999.2.0",
            since: "9999.1.0",
            items: WhatsNewFixture.items(["9999.2.0", "9999.1.0"])
        )
        relaunch.next = Self.list
        record.markRelaunch(relaunch)
        var shown: WhatsNewWindowController?
        coordinator.presents = { shown = $0 }
        #expect(
            coordinator.relaunched(
                opensWindow: true,
                narration: BootNarration()
            )
        )
        #expect(shown?.next == Self.list)
        #expect(asked.urls.isEmpty)
    }

    /// The record crosses the update: the build that writes it
    /// predates the list, so its absence must still read.
    @Test("a relaunch record written before the list still reads")
    func olderRecordReads() throws {
        let json = #"{"version":"2.1.0","since":"2.0.0","items":[]}"#
        let relaunch = try JSONDecoder().decode(
            WhatsNewRecord.Relaunch.self,
            from: Data(json.utf8)
        )
        #expect(relaunch.version == "2.1.0")
        #expect(relaunch.next == nil)
    }

    /// A later build may store the list another way: an unreadable
    /// one costs the card, never the relaunch's notes.
    @Test("an unreadable carried list leaves the relaunch intact")
    func unreadableListKeepsTheRecord() throws {
        let json =
            #"{"version":"2.1.0","since":"2.0.0","items":[],"#
            + #""next":{"shape":"from a later build"}}"#
        let relaunch = try JSONDecoder().decode(
            WhatsNewRecord.Relaunch.self,
            from: Data(json.utf8)
        )
        #expect(relaunch.version == "2.1.0")
        #expect(relaunch.next == nil)
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

    @Test("the offer's fetch rides the relaunch record")
    func offerFetchIsCarried() async throws {
        let driver = UpdatePromptDriver(
            hostBundle: Bundle.main,
            delegate: UpdatePromptPolicy()
        )
        driver.presents = { _ in }
        driver.seenRecord = WhatsNewRecord(
            UserDefaults(suiteName: "NextOnMyListWiringTests.\(UUID())")!
        )
        driver.sparkleError = { _, _ in }
        driver.sparkleReadyToInstall = { .dismiss }
        driver.fetchNext = { Self.list }
        driver.showUpdateFound(
            try Self.item("9999.1.0"),
            userInitiated: true,
            stage: .notDownloaded
        ) { _ in }
        // Read before the await: an absent handle awaits nothing.
        let fetch = try #require(driver.nextFetch)
        await fetch.value
        try #require(driver.window?.session).install()
        driver.showInstallingUpdate(
            withApplicationTerminated: false,
            retryTerminatingApplication: {}
        )
        let relaunch = try #require(driver.seenRecord?.takeRelaunch())
        #expect(relaunch.next == Self.list)
    }

    /// The driver's fetch is inert unless the live updater wires
    /// it, so the wiring is pinned where it is written.
    @Test("the live updater wires the fetch to Sparkle's feed")
    func liveUpdaterWiresTheFetch() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Updates/AppUpdater.swift"
                )
        )
        #expect(
            source.components(separatedBy: "driver.fetchNext = {").count
                == 2
        )
        #expect(source.contains("guard let feed = updater.feedURL"))
        #expect(
            source.contains("await NextOnMyList.fetch(besideFeed: feed)")
        )
    }

    /// Both sides of the inverted seam (tests.md): the driver's
    /// fetch has no default and one writer, while the coordinator's
    /// default is the live fetch every launch takes.
    @Test("the driver's fetch is inert by default, the launch's live")
    func seamDefaults() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        func source(_ file: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(
                    "Sources/KiwiDesk/Updates/\(file)"
                )
            )
        }
        let driver = try source("UpdatePromptDriver.swift")
        #expect(
            driver.contains(
                "var fetchNext: (() async -> NextOnMyList?)?\n"
            )
        )
        var writers = 0
        let enumerator = FileManager.default.enumerator(
            at: root.appendingPathComponent("Sources"),
            includingPropertiesForKeys: nil
        )
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            writers +=
                try SourceScan.strippedSource(at: url)
                .components(separatedBy: ".fetchNext = {").count - 1
        }
        #expect(writers == 1)
        let coordinator = try source("WhatsNewCoordinator.swift")
        #expect(
            coordinator.contains(
                "await NextOnMyList.fetch(besideFeed: $0)"
            )
        )
    }
}
