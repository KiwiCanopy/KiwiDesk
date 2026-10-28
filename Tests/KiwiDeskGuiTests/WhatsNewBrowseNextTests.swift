import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Home's "What's new" ends on "Next on my list" as the owed notes
/// do (#1813, #2308): a read list goes on the window and into the
/// cache, and a window opened from the cache carries the cached
/// list until the read replaces it.
@MainActor
@Suite("What's new from Home: Next on my list", .serialized)
struct WhatsNewBrowseNextTests {
    private final class Log {
        var shown: [WhatsNewWindowController] = []
    }

    private static func coordinator(
        feed: [WhatsNewFeed.Item]?,
        next: NextOnMyList?
    ) throws -> (WhatsNewCoordinator, WhatsNewRecord, Log) {
        let (coordinator, record, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: feed
        )
        coordinator.fetchNext = { _ in next }
        let log = Log()
        coordinator.presents = { log.shown.append($0) }
        return (coordinator, record, log)
    }

    private static func list(_ item: String) -> NextOnMyList {
        NextOnMyList(asOf: Date(), items: [item])
    }

    @Test("A read list goes on the window and into the cache")
    func readListIsShownAndCached() async throws {
        let list = Self.list("A bigger pocket")
        let (coordinator, record, log) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0"]),
            next: list
        )
        coordinator.browse()
        await coordinator.browseFetch?.value
        #expect(try #require(log.shown.first).next == list)
        #expect(record.cachedNext == list)
    }

    @Test("From the cache it carries the cached list, offline too")
    func cachedListRidesTheCache() async throws {
        let list = Self.list("A bigger pocket")
        let (coordinator, record, log) = try Self.coordinator(
            feed: nil,
            next: nil
        )
        record.cacheFeed(WhatsNewFixture.items(["9999.2.0"]))
        record.cacheNext(list)
        coordinator.browse()
        #expect(try #require(log.shown.first).next == list)
        await coordinator.browseFetch?.value
        // An offline read keeps the last list rather than erasing it.
        #expect(record.cachedNext == list)
    }

    @Test("A list past its age is left off the window")
    func staleListIsHidden() async throws {
        let stale = NextOnMyList(
            asOf: Date().addingTimeInterval(-NextOnMyList.maxAge - 86_400),
            items: ["Old"]
        )
        let (coordinator, _, log) = try Self.coordinator(
            feed: WhatsNewFixture.items(["9999.2.0"]),
            next: stale
        )
        coordinator.browse()
        await coordinator.browseFetch?.value
        #expect(try #require(log.shown.first).next == nil)
    }
}
