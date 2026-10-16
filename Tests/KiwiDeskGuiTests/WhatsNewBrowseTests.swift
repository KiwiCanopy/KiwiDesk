import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Home's "What's new" (#2308): it opens the running version's
/// notes with the release menu, from the cache when offline,
/// answers nothing, yields to an update offer and to owed notes,
/// and shares the one window slot with them. The cache is
/// replaced by each read.
@MainActor
@Suite("What's new from Home (#2308)", .serialized)
struct WhatsNewBrowseTests {
    private final class Log {
        var shown: [WhatsNewWindowController] = []
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
        #expect(shown.menu?.opening == .release("9999.2.0"))
        #expect(
            shown.menu?.releases.options == [
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
        #expect(coordinator.window == nil)
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
        #expect(log.shown.first?.menu?.releases.options.count == 2)
    }

    @Test("Offline with nothing cached it opens with no notes and no menu")
    func opensUnreadOffline() async throws {
        let (coordinator, _, log) = try Self.coordinator(feed: nil)
        coordinator.browse()
        #expect(log.shown.isEmpty)
        await coordinator.browseFetch?.value
        let shown = try #require(log.shown.first)
        #expect(shown.menu == nil)
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
        let shown = try #require(log.shown.first)
        #expect(shown.menu?.opening == .since("9999.1.0"))
        #expect(shown.offer.digest == coordinator.waiting?.digest)
        shown.finish()
        #expect(record.lastRun == "9999.3.0")
    }

    @Test("Owed notes replace Home's window: one is up at a time")
    func owedReplacesHome() async throws {
        let (coordinator, _, log) = try Self.coordinator(
            current: "9999.3.0",
            feed: WhatsNewFixture.items(["9999.3.0", "9999.2.0", "9999.1.0"])
        )
        coordinator.browse()
        await coordinator.browseFetch?.value
        let home = try #require(log.shown.first)
        await coordinator.launched(opensWindow: true, existingUser: true)
        let owed = try #require(coordinator.window)
        #expect(owed !== home)
        #expect(log.shown.last === owed)
        // Home's late close cannot take the owed window down.
        home.finish()
        #expect(coordinator.window === owed)
    }

    @Test("An update offer on screen comes forward instead, owed notes too")
    func offerComesForward() async throws {
        let (coordinator, _, log) = try Self.coordinator(
            current: "9999.3.0",
            feed: WhatsNewFixture.items(["9999.3.0", "9999.2.0"])
        )
        await coordinator.launched(opensWindow: false, existingUser: true)
        var fronted = 0
        coordinator.frontsUpdateOffer = {
            fronted += 1
            return true
        }
        coordinator.browse()
        #expect(fronted == 1)
        #expect(log.shown.isEmpty)
        #expect(coordinator.browseFetch == nil)
    }

    @Test("An offer that opens during the read keeps the screen")
    func offerDuringReadWins() async throws {
        let (coordinator, _, log) = try Self.coordinator(feed: nil)
        var offerOpen = false
        coordinator.updateOfferOpen = { offerOpen }
        coordinator.fetch = { _ in
            offerOpen = true
            return WhatsNewFixture.items(["9999.2.0"])
        }
        coordinator.browse()
        await coordinator.browseFetch?.value
        #expect(log.shown.isEmpty)
    }

    @Test("The launch's read caches the feed too")
    func readsCache() async throws {
        let (coordinator, record, _) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0", "9999.1.0"])
        )
        await coordinator.launched(opensWindow: false, existingUser: true)
        #expect(record.cachedFeed.map(\.version) == ["9999.2.0", "9999.1.0"])
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

    @Test("The live updater fronts only an offer, and says so")
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
                    + "guarddriver.current?.isOffer==trueelse{returnfalse}"
                    + "returndriver.focusOpenWindow()}"
            )
        )
    }
}
