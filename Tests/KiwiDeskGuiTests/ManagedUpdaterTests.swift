import Foundation
import Testing

@testable import KiwiDesk

/// A package-managed copy keeps What's new (#2911): the notes for a
/// version Home Manager switched to wait as they do after a Sparkle
/// install, read from the bundle's own feed.
@MainActor
@Suite("Managed copy's What's new (#2911)")
struct ManagedUpdaterTests {
    private static func updater(
        current: String,
        lastRun: String
    ) throws -> ManagedUpdater {
        let record = WhatsNewRecord(makeScratchDefaults().defaults)
        record.markAnswered(lastRun)
        return ManagedUpdater(
            manager: "Home Manager",
            host: try FeedFixture.host(version: current),
            record: record
        )
    }

    @Test("a switch to a newer version owes its notes")
    func switchOwesNotes() async throws {
        let updater = try Self.updater(current: "4.2.0", lastRun: "4.1.0")
        let whatsNew = try #require(updater.whatsNew)
        whatsNew.fetch = { _ in WhatsNewFixture.items(["4.2.0", "4.1.0"]) }
        whatsNew.fetchNext = { _ in nil }
        whatsNew.presents = { _ in }

        await whatsNew.launched(opensWindow: false, existingUser: true)

        #expect(whatsNew.waiting?.version == "4.2.0")
    }

    @Test("the same version owes nothing")
    func sameVersionOwesNothing() async throws {
        let updater = try Self.updater(current: "4.2.0", lastRun: "4.2.0")
        let whatsNew = try #require(updater.whatsNew)
        whatsNew.fetch = { _ in WhatsNewFixture.items(["4.2.0"]) }
        whatsNew.fetchNext = { _ in nil }

        await whatsNew.launched(opensWindow: false, existingUser: true)

        #expect(whatsNew.waiting == nil)
    }

    /// The feed the notes come from is the bundle's, or the
    /// `SUFeedURL` default Sparkle would read first.
    @Test("the feed is the default's, else the bundle's")
    func feedResolvesLikeSparkle() throws {
        let host = try FeedFixture.host(version: "4.2.0")
        let (defaults, name) = makeScratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(
            ManagedUpdater.feedURL(of: host, defaults: defaults)
                == URL(string: "https://example.invalid/appcast.xml")
        )
        defaults.set("https://example.invalid/test.xml", forKey: "SUFeedURL")
        #expect(
            ManagedUpdater.feedURL(of: host, defaults: defaults)
                == URL(string: "https://example.invalid/test.xml")
        )
    }

    /// A Home Manager rollback is routine: 4.2 → 4.1 → 4.2 must not
    /// owe 4.2's notes a second time.
    @Test("a rollback and roll forward owes nothing twice")
    func rollbackKeepsTheRecord() async throws {
        let (defaults, name) = makeScratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let record = WhatsNewRecord(defaults)
        record.markAnswered("4.2.0")
        for version in ["4.1.0", "4.2.0"] {
            let whatsNew = try #require(
                ManagedUpdater(
                    manager: "Home Manager",
                    host: try FeedFixture.host(version: version),
                    record: record
                ).whatsNew
            )
            whatsNew.fetch = { _ in
                WhatsNewFixture.items(["4.2.0", "4.1.0"])
            }
            whatsNew.fetchNext = { _ in nil }

            await whatsNew.launched(opensWindow: false, existingUser: true)

            #expect(whatsNew.waiting == nil, Comment(rawValue: version))
            #expect(record.lastRun == "4.2.0", Comment(rawValue: version))
        }
    }

    /// The managed copy reads the feed itself; a Sparkle delegate
    /// choosing another feed would leave it on the old one.
    @Test("production gives Sparkle no feed of its own to pick")
    func noFeedDelegate() throws {
        let tree = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let sites = try SourceScan.identifierSites(
            of: "feedURLString",
            under: tree
        )
        #expect(sites.isEmpty, Comment(rawValue: "\(sites.map(\.site))"))
    }

    @Test("a managed copy still never checks or installs")
    func neverChecks() throws {
        let updater = try Self.updater(current: "4.2.0", lastRun: "4.1.0")
        #expect(!updater.canCheckForUpdates)
        #expect(!updater.updatePending)
    }
}
