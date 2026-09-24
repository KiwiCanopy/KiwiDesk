import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Shared by the What's new suites (#1542): notes, feed items, a
/// coordinator over a throwaway host, and the fakes the status
/// item takes.
@MainActor
enum WhatsNewFixture {
    static func notes(_ entry: String) -> String {
        """
        {"format":1,"summary":"S.","sections":\
        [{"type":"new","title":"New","items":["\(entry)"]}]}
        """
    }

    static func items(_ versions: [String]) -> [WhatsNewFeed.Item] {
        versions.map {
            .init(version: $0, shown: $0, released: nil, notes: notes($0))
        }
    }

    final class Log {
        var presented = 0
    }

    /// A coordinator on a host bundle reporting `current`, with the
    /// feed handed in.
    static func coordinator(
        current: String,
        lastRun: String?,
        feed: [WhatsNewFeed.Item]?
    ) throws -> (WhatsNewCoordinator, WhatsNewRecord, Log) {
        let record = WhatsNewRecord(
            UserDefaults(suiteName: "WhatsNewTests.\(UUID())")!
        )
        if let lastRun { record.markAnswered(lastRun) }
        let host = try FeedFixture.host(version: current)
        let coordinator = WhatsNewCoordinator(
            record: record,
            host: host,
            feedURL: { URL(string: "https://example.invalid/appcast.xml") }
        )
        let log = Log()
        coordinator.fetch = { _ in feed }
        coordinator.presents = { _ in log.presented += 1 }
        return (coordinator, record, log)
    }

}

@MainActor
final class WhatsNewFakeUpdater: AppUpdating {
    let whatsNew: WhatsNewCoordinator?
    let updates = UpdateStateStore()
    var canCheckForUpdates = true
    var updatePending = false { didSet { onUpdatePendingChanged() } }
    var onUpdatePendingChanged: () -> Void = {}
    func checkForUpdates() {}

    init(whatsNew: WhatsNewCoordinator) {
        self.whatsNew = whatsNew
    }
}

@MainActor
final class RowFakeStatusItem: StatusItemHandle {
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
