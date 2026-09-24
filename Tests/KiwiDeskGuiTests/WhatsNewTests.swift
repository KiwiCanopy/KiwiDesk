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

    private static func notes(_ entry: String) -> String {
        """
        {"format":1,"summary":"S.","sections":\
        [{"type":"new","title":"New","items":["\(entry)"]}]}
        """
    }

    private static func items(_ versions: [String]) -> [WhatsNewFeed.Item] {
        versions.map {
            .init(version: $0, shown: $0, released: nil, notes: notes($0))
        }
    }

    private final class Log {
        var presented = 0
    }

    /// A coordinator on a host bundle reporting `current`, with the
    /// feed handed in.
    private func coordinator(
        current: String,
        lastRun: String?,
        feed: [WhatsNewFeed.Item]?
    ) throws -> (WhatsNewCoordinator, WhatsNewRecord, Log) {
        let record = WhatsNewRecord(Self.defaults())
        if let lastRun { record.markAnswered(lastRun) }
        let host = try FeedFixture.host(version: current)
        let coordinator = WhatsNewCoordinator(record: record, host: host)
        let log = Log()
        coordinator.fetch = { _ in feed }
        coordinator.presents = { _ in log.presented += 1 }
        return (coordinator, record, log)
    }

    @Test("a launch the user started opens it")
    func userLaunchOpens() async throws {
        let (coordinator, record, log) = try coordinator(
            current: "9999.2.0",
            lastRun: "9999.0.0",
            feed: Self.items(["9999.2.0", "9999.1.0", "9999.0.0"])
        )
        await coordinator.launched(userStarted: true, existingUser: true)
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
        let (coordinator, _, log) = try coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: Self.items(["9999.2.0"])
        )
        await coordinator.launched(userStarted: false, existingUser: true)
        #expect(log.presented == 0)
        #expect(coordinator.waiting?.version == "9999.2.0")
        coordinator.show()
        #expect(log.presented == 1)
    }

    @Test("offline, it stays owed for the next launch")
    func offlineStaysOwed() async throws {
        let (coordinator, record, log) = try coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: nil
        )
        await coordinator.launched(userStarted: true, existingUser: true)
        #expect(log.presented == 0)
        #expect(record.lastRun == "9999.1.0")
    }

    @Test("a launch that owes nothing records the version")
    func nothingOwedRecords() async throws {
        let (coordinator, record, log) = try coordinator(
            current: "9999.2.0",
            lastRun: nil,
            feed: Self.items(["9999.2.0"])
        )
        await coordinator.launched(userStarted: true, existingUser: false)
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

    @Test("the quick menu offers What's New only while it waits")
    func quickMenuRow() async throws {
        LocalizationManager.shared.select("en")
        let (coordinator, _, _) = try coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: Self.items(["9999.2.0"])
        )
        let controller = StatusItemController(item: RowFakeStatusItem())
        controller.whatsNew = coordinator
        #expect(controller.makeWhatsNewItem() == nil)
        await coordinator.launched(userStarted: false, existingUser: true)
        let row = try #require(controller.makeWhatsNewItem())
        #expect(row.title == "What's New in KiwiDesk 9999.2.0…")
        #expect(row.isEnabled)
        #expect(row.target === controller)
    }
}

@MainActor
private final class RowFakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = NSStatusBarButton()
    var menu: NSMenu?
}

/// Fixtures: a feed from the real generator, and a host bundle
/// reporting a version.
enum FeedFixture {
    static func feed(versions: [String]) throws -> Data {
        func asset(_ tag: String, _ name: String, _ size: Int) -> [String: Any]
        {
            [
                "name": name, "size": size,
                "browser_download_url":
                    "https://example.invalid/\(tag)/\(name)",
                "url": "https://api.github.com/assets/9",
            ]
        }
        let releases: [[String: Any]] = versions.enumerated().map { index, v in
            let tag = "v\(v)"
            let archive = "KiwiDesk-\(v).zip"
            return [
                "tag_name": tag,
                "published_at": "2026-09-2\(4 - index)T10:00:00Z",
                "draft": false,
                "edsig": Data(repeating: 0x41, count: 64)
                    .base64EncodedString(),
                "assets": [
                    asset(tag, archive, 9_123_456),
                    asset(tag, "\(archive).edsig", 89),
                ],
            ]
        }
        let notes: [String: Any] = [
            "generated_by": "WhatsNewTests",
            "releases": versions.map {
                [
                    "tag": "v\($0)", "version": $0, "summary": "S.",
                    "sections": [
                        ["title": "New", "type": "new", "items": ["A."]]
                    ],
                ]
            },
        ]
        let dir = FileManager.default.temporaryDirectory
        let releasesFile = dir.appendingPathComponent("wn-r-\(UUID()).json")
        let notesFile = dir.appendingPathComponent("wn-n-\(UUID()).json")
        try JSONSerialization.data(withJSONObject: releases)
            .write(to: releasesFile)
        try JSONSerialization.data(withJSONObject: notes)
            .write(to: notesFile)
        defer {
            try? FileManager.default.removeItem(at: releasesFile)
            try? FileManager.default.removeItem(at: notesFile)
        }
        let script = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("scripts/appcast-sync").path
        let run = try GuiScriptFixture.python([
            script, "--all", "--releases", releasesFile.path,
            "--notes", notesFile.path, "--output", "-",
        ])
        #expect(run.status == 0, "\(run.stderr)")
        return Data(run.stdout.utf8)
    }

    /// A throwaway bundle whose Info.plist carries the version and
    /// a feed URL — the coordinator reads both off its host.
    static func host(version: String) throws -> Bundle {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wn-host-\(UUID()).bundle")
        let contents = dir.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(
            at: contents,
            withIntermediateDirectories: true
        )
        let plist: [String: Any] = [
            "CFBundleIdentifier": "test.whatsnew.\(UUID())",
            "CFBundleVersion": version,
            "SUFeedURL": "https://example.invalid/appcast.xml",
        ]
        try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        ).write(to: contents.appendingPathComponent("Info.plist"))
        return try #require(Bundle(url: dir))
    }
}
