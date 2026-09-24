import AppKit
import Sparkle
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// "What's new in X" after an update (#1542 ruling ▸ After the
/// update; owner, 2026-09-24: fetch the feed, keep the record in
/// the app's own defaults).
@MainActor
@Suite("What's new (#1542)", .serialized)
struct WhatsNewTests {
    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: "WhatsNewTests.\(UUID())")!
    }

    private static func compare(_ a: String, _ b: String)
        -> ComparisonResult
    {
        a.compare(b, options: .numeric)
    }

    private static func due(
        current: String = "2.1.0",
        lastRun: String?,
        seen: String? = nil,
        existingUser: Bool = true
    ) -> WhatsNewDue? {
        WhatsNewRecord.due(
            current: current,
            lastRun: lastRun,
            seen: seen,
            existingUser: existingUser,
            compare: compare
        )
    }

    // MARK: - When it is owed

    @Test("a newer version owes everything since the last run")
    func newerVersionIsOwed() {
        #expect(Self.due(lastRun: "2.0.0") == WhatsNewDue(since: "2.0.0"))
        #expect(Self.due(lastRun: "2.1.0") == nil)
        #expect(Self.due(lastRun: "2.2.0") == nil)
    }

    /// Never after a clicked Install: the notes were read there.
    @Test("a version installed from the window owes nothing")
    func seenOwesNothing() {
        #expect(Self.due(lastRun: "2.0.0", seen: "2.1.0") == nil)
        #expect(
            Self.due(lastRun: "2.0.0", seen: "2.0.5")
                == WhatsNewDue(since: "2.0.0")
        )
    }

    /// 1.x never recorded a version: an existing user is on the
    /// 1.x → 2.0.0 jump, a fresh install gets the tour instead.
    @Test("no record: an existing user is owed, a fresh one is not")
    func noRecord() {
        #expect(Self.due(lastRun: nil) == WhatsNewDue(since: nil))
        #expect(Self.due(lastRun: nil, existingUser: false) == nil)
    }

    // MARK: - The feed

    /// Read off a real `appcast-sync` run, so the reader and the
    /// generator agree on the element, the version and the date.
    @Test("the feed reader reads what appcast-sync writes")
    func feedReaderReadsTheGenerator() throws {
        let data = try FeedFixture.feed(
            versions: ["9999.2.0", "9999.1.0"]
        )
        let items = WhatsNewFeed.items(from: data)
        #expect(items.map(\.version) == ["9999.2.0", "9999.1.0"])
        #expect(items.allSatisfy { $0.released != nil })
        #expect(
            items.allSatisfy { ReleaseNotes.decode($0.notes) != nil }
        )
    }

    @Test("a malformed feed reads as no items")
    func malformedFeed() {
        #expect(WhatsNewFeed.items(from: Data("<rss".utf8)).isEmpty)
    }

    // MARK: - The launch

    @Test("a launch the user started opens it")
    func userLaunchOpens() async throws {
        let (coordinator, record, log) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.0.0",
            feed: WhatsNewFixture.items(["9999.2.0", "9999.1.0", "9999.0.0"])
        )
        await coordinator.launched(opensWindow: true, existingUser: true)
        #expect(log.presented == 1)
        #expect(
            coordinator.waiting?.digest?.versions == ["9999.2.0", "9999.1.0"]
        )
        // Not answered until Done.
        #expect(record.lastRun == "9999.0.0")
    }

    /// A login launch leaves the mark and the row, never the window.
    @Test("a login launch waits behind the mark")
    func loginLaunchWaits() async throws {
        let (coordinator, _, log) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        await coordinator.launched(opensWindow: false, existingUser: true)
        #expect(log.presented == 0)
        #expect(coordinator.waiting?.version == "9999.2.0")
        coordinator.show()
        #expect(log.presented == 1)
    }

    @Test("offline, it stays owed for the next launch")
    func offlineStaysOwed() async throws {
        let (coordinator, record, log) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: nil
        )
        await coordinator.launched(opensWindow: true, existingUser: true)
        #expect(log.presented == 0)
        #expect(record.lastRun == "9999.1.0")
    }

    @Test("a launch that owes nothing records the version")
    func nothingOwedRecords() async throws {
        let (coordinator, record, log) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: nil,
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        await coordinator.launched(opensWindow: true, existingUser: false)
        #expect(log.presented == 0)
        #expect(record.lastRun == "9999.2.0")
    }

    // MARK: - Seen, and the row

    @Test("the window's own Install records the notes as read")
    func installRecordsSeen() {
        var seen = 0
        let session = UpdateSession(
            reply: { _ in },
            installsFrom: .downloading(received: 0, expected: nil)
        )
        session.onInstall = { seen += 1 }
        session.install()
        session.install()
        #expect(seen == 1)
    }

    /// A version the feed does not list yet — a direct download
    /// ahead of the feed — stays owed; one listed with notes the
    /// window cannot read is answered.
    @Test("an unlisted version stays owed, an unreadable one is answered")
    func unlistedAndUnreadable() async throws {
        let (unlisted, unlistedRecord, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: WhatsNewFixture.items(["9999.1.0"])
        )
        await unlisted.launched(opensWindow: true, existingUser: true)
        #expect(unlistedRecord.lastRun == "9999.1.0")
        let (unreadable, unreadableRecord, log) =
            try WhatsNewFixture.coordinator(
                current: "9999.2.0",
                lastRun: "9999.1.0",
                feed: [
                    .init(
                        version: "9999.2.0",
                        shown: "9999.2.0",
                        released: nil,
                        notes: "{broken"
                    )
                ]
            )
        await unreadable.launched(opensWindow: true, existingUser: true)
        #expect(unreadableRecord.lastRun == "9999.2.0")
        #expect(log.presented == 0)
    }

    /// The 1.x jump: no start recorded, so every typed version up
    /// to the running one, and untyped 1.x releases dropped
    /// silently rather than each linked.
    @Test("a 1.x upgrade merges every typed version, silently")
    func upgradeFromOneX() async throws {
        let untyped = WhatsNewFeed.Item(
            version: "9999.0.5",
            shown: "9999.0.5",
            released: nil,
            notes: nil
        )
        let (coordinator, _, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: nil,
            feed: WhatsNewFixture.items(["9999.2.0", "9999.1.0"]) + [untyped]
        )
        await coordinator.launched(opensWindow: false, existingUser: true)
        let digest = try #require(coordinator.waiting?.digest)
        #expect(digest.versions == ["9999.2.0", "9999.1.0"])
        #expect(digest.unreadable.isEmpty)
    }

}
