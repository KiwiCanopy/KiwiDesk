import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Home's "What's new" ends on "Next on my list" as the owed notes
/// do (#1813, #2308). Each read files the list over the cache — a
/// list replaces it, an emptied section clears it, a failed read
/// keeps it — and a window opens on the cached list as it stood.
@MainActor
@Suite("What's new from Home: Next on my list", .serialized)
struct WhatsNewBrowseNextTests {
    private final class Log {
        var shown: [WhatsNewWindowController] = []
    }

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func coordinator(
        feed: [WhatsNewFeed.Item]?,
        next: NextOnMyList.Read
    ) throws -> (WhatsNewCoordinator, WhatsNewRecord, Log) {
        let (coordinator, record, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: feed
        )
        coordinator.readNext = { _ in next }
        coordinator.now = { Self.now }
        let log = Log()
        coordinator.presents = { log.shown.append($0) }
        return (coordinator, record, log)
    }

    private static func list(
        _ item: String,
        age: TimeInterval = 0
    ) -> NextOnMyList {
        NextOnMyList(asOf: now.addingTimeInterval(-age), items: [item])
    }

    @Test("A read list goes on the window and into the cache")
    func readListIsShownAndCached() async throws {
        let list = Self.list("A bigger pocket")
        let (coordinator, record, log) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0"]),
            next: .list(list)
        )
        coordinator.browse()
        await coordinator.browseFetch?.value
        #expect(try #require(log.shown.first).next == list)
        #expect(record.cachedNext == list)
    }

    @Test("From the cache it opens on the cached list; a failed read keeps it")
    func cachedListRidesTheCache() async throws {
        let list = Self.list("A bigger pocket")
        let (coordinator, record, log) = try Self.coordinator(
            feed: nil,
            next: .unreadable
        )
        record.cacheFeed(WhatsNewFixture.items(["9999.2.0"]))
        record.cacheNext(.list(list))
        coordinator.browse()
        #expect(try #require(log.shown.first).next == list)
        await coordinator.browseFetch?.value
        #expect(record.cachedNext == list)
    }

    @Test("With no feed cached, an offline open still carries the list")
    func uncachedFeedOpensOnTheCachedList() async throws {
        let list = Self.list("A bigger pocket")
        let (coordinator, record, log) = try Self.coordinator(
            feed: nil,
            next: .unreadable
        )
        record.cacheNext(.list(list))
        coordinator.browse()
        #expect(log.shown.isEmpty)
        await coordinator.browseFetch?.value
        #expect(try #require(log.shown.first).next == list)
    }

    @Test("An emptied section clears the cached list")
    func emptiedSectionClears() async throws {
        let (coordinator, record, log) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0"]),
            next: .emptied
        )
        record.cacheNext(.list(Self.list("Shipped already")))
        coordinator.browse()
        await coordinator.browseFetch?.value
        #expect(record.cachedNext == nil)
        #expect(try #require(log.shown.first).next == nil)
    }

    @Test("A list past its age is left off the window")
    func staleListIsHidden() async throws {
        let stale = Self.list("Old", age: NextOnMyList.maxAge + 86_400)
        let (coordinator, _, log) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0"]),
            next: .list(stale)
        )
        coordinator.browse()
        await coordinator.browseFetch?.value
        #expect(try #require(log.shown.first).next == nil)
    }

    @Test("Owed notes file the list they read for Home's window")
    func owedReadFillsTheCache() async throws {
        let list = Self.list("A bigger pocket")
        let (coordinator, record, _) = try WhatsNewFixture.coordinator(
            current: "9999.3.0",
            lastRun: "9999.2.0",
            feed: WhatsNewFixture.items(["9999.3.0", "9999.2.0"])
        )
        coordinator.fetchNext = { _ in list }
        await coordinator.launched(opensWindow: false, existingUser: true)
        #expect(record.cachedNext == list)
    }
}
