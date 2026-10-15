import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Home's "What's new" (#2308): it opens the running version's
/// notes with the release menu, from the cache when offline,
/// answers nothing, and yields to owed notes and to an update
/// offer on screen. The cache is replaced by each read.
@MainActor
@Suite("What's new from Home (#2308)", .serialized)
struct WhatsNewBrowseTests {
    private final class Log {
        var shown: [WhatsNewWindowController] = []
        var offerFronted = 0
    }

    private static func coordinator(
        current: String = "9999.2.0",
        lastRun: String? = "9999.1.0",
        feed: [WhatsNewFeed.Item]?
    ) throws -> (WhatsNewCoordinator, WhatsNewRecord, Log) {
        let (coordinator, record, _) = try WhatsNewFixture.coordinator(
            current: current,
            lastRun: lastRun,
            feed: feed
        )
        let log = Log()
        coordinator.presents = { log.shown.append($0) }
        coordinator.frontsUpdateOffer = { log.offerFronted += 1 }
        return (coordinator, record, log)
    }

    @Test("Opens on the running version with the menu, and caches the feed")
    func opensRunningVersion() async throws {
        let (coordinator, record, log) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0", "9999.1.0"])
        )
        coordinator.browse()
        await coordinator.browseFetch?.value
        let shown = try #require(log.shown.first)
        #expect(log.shown.count == 1)
        #expect(shown.opening == .release("9999.2.0"))
        #expect(
            shown.releases?.options == [
                .release("9999.2.0"), .release("9999.1.0"),
            ]
        )
        #expect(record.cachedFeed.map(\.version) == ["9999.2.0", "9999.1.0"])
    }

    @Test("Its Done answers nothing")
    func doneAnswersNothing() async throws {
        let (coordinator, record, log) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        coordinator.browse()
        await coordinator.browseFetch?.value
        try #require(log.shown.first).finish()
        #expect(coordinator.browsing == nil)
        #expect(record.lastRun == "9999.1.0")
        #expect(coordinator.waiting == nil)
    }

    @Test("Offline it opens from the cache at once")
    func opensFromCache() async throws {
        let (coordinator, record, log) = try Self.coordinator(feed: nil)
        record.cacheFeed(WhatsNewFixture.items(["9999.2.0", "9999.1.0"]))
        coordinator.browse()
        #expect(log.shown.count == 1)
        await coordinator.browseFetch?.value
        #expect(log.shown.count == 1)
        #expect(log.shown.first?.releases?.options.count == 2)
    }

    @Test("Offline with nothing cached it opens with no notes and no menu")
    func opensUnreadOffline() async throws {
        let (coordinator, _, log) = try Self.coordinator(feed: nil)
        coordinator.browse()
        #expect(log.shown.isEmpty)
        await coordinator.browseFetch?.value
        let shown = try #require(log.shown.first)
        #expect(shown.releases == nil)
        #expect(shown.offer.digest == nil)
    }

    @Test("A second press fronts the same window")
    func secondPressFronts() async throws {
        let (coordinator, _, log) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        coordinator.browse()
        await coordinator.browseFetch?.value
        coordinator.browse()
        #expect(log.shown.count == 2)
        #expect(log.shown[0] === log.shown[1])
    }

    @Test("Owed notes open as owed, and their Done answers them")
    func owedNotesWin() async throws {
        let (coordinator, record, log) = try Self.coordinator(
            current: "9999.3.0",
            feed: WhatsNewFixture.items(["9999.3.0", "9999.2.0", "9999.1.0"])
        )
        await coordinator.launched(opensWindow: false, existingUser: true)
        coordinator.browse()
        #expect(coordinator.browsing == nil)
        let shown = try #require(log.shown.first)
        #expect(shown.opening == .since("9999.1.0"))
        shown.finish()
        #expect(record.lastRun == "9999.3.0")
    }

    @Test("An update offer on screen comes forward instead")
    func offerComesForward() throws {
        let (coordinator, _, log) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        coordinator.updateOfferOpen = { true }
        coordinator.browse()
        #expect(log.offerFronted == 1)
        #expect(log.shown.isEmpty)
        #expect(coordinator.browseFetch == nil)
    }

    @Test("The cache is replaced by each read, never added to")
    func cacheIsReplaced() throws {
        let (_, record, _) = try Self.coordinator(feed: nil)
        record.cacheFeed(WhatsNewFixture.items(["9999.2.0", "9999.1.0"]))
        record.cacheFeed(WhatsNewFixture.items(["9999.3.0"]))
        #expect(record.cachedFeed.map(\.version) == ["9999.3.0"])
        // A read with no readable notes keeps what was cached.
        record.cacheFeed([
            .init(
                version: "9999.4.0",
                shown: "9999.4.0",
                released: nil,
                notes: nil
            )
        ])
        #expect(record.cachedFeed.map(\.version) == ["9999.3.0"])
    }

    @Test("The live updater fronts its offer for Home's What's new")
    func liveUpdaterWiresTheOffer() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Updates/AppUpdater.swift"
            )
        let source = try SourceScan.blankedSource(at: url)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            source.contains(
                "whatsNew?.frontsUpdateOffer={[driver]in"
                    + "_=driver.focusOpenWindow()}"
            )
        )
    }
}
