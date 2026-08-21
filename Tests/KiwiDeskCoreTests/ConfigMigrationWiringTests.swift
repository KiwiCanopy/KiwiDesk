import Foundation
import Testing

@testable import KiwiDeskCore

/// The crossing as production reaches it — a file on disk,
/// through the readers the app actually uses.
///
/// Split from `ConfigMigrationTests` at the §2.1 ceiling, and the
/// split follows the fault line: that suite proves the rewrite is
/// correct, this one proves anything calls it. Both were needed
/// separately — removing the hop from `ProfileManager.read` left
/// every test in the other suite green, and the second reader
/// (`KiwiCore.readBackup`) had no hop at all for a commit.
/// `ConfigMigrationRoutingTests` guards the census itself.
@Suite("Config migration wiring")
struct ConfigMigrationWiringTests {

    /// A scratch config directory, cleaned up by the test.
    private func scratch() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-migration-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    /// A v0.9.7 profile FILE loads, and is repaired on disk.
    ///
    /// The migration being correct proves nothing about anything
    /// calling it: removing the hop from `ProfileManager.read`
    /// left every other test here green (mutation, 2026-08-20).
    /// This is the path a user actually meets — the file on disk,
    /// through the reader the app uses.
    @MainActor
    @Test("A v0.9.7 profile file loads through the manager")
    func profileFileMigratesOnRead() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        var settings = TilingSettings()
        settings.appBarStyle.content = .iconAndTitle
        let manager = ProfileManager(directory: dir)
        try manager.save(
            Profile(
                name: "Starter",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [SpaceID(1): .monocle],
                settings: settings
            )
        )
        let file = dir.appendingPathComponent("Starter.json")
        try Data(
            String(
                decoding: try Data(contentsOf: file),
                as: UTF8.self
            )
            .replacingOccurrences(
                of: "\"icon_and_title\"",
                with: "\"icon_and_name\""
            )
            .replacingOccurrences(
                of: "  \"format\" : 1,\n",
                with: ""
            ).utf8
        ).write(to: file)

        #expect(
            String(
                decoding: try Data(contentsOf: file),
                as: UTF8.self
            ).contains("icon_and_name")
        )

        let profile = try manager.read(name: "Starter")
        #expect(
            profile.settings.appBarStyle.content == .iconAndTitle
        )
        // Repaired in place, so the crossing runs once rather
        // than on every launch forever.
        let onDisk = String(
            decoding: try Data(contentsOf: file),
            as: UTF8.self
        )
        #expect(!onDisk.contains("icon_and_name"))
        // ...and it is listed, which is the whole point: an
        // unmigrated file is SKIPPED by `allProfiles()`.
        #expect(manager.allProfiles().map(\.name) == ["Starter"])
    }

    /// A v0.9.7 BACKUP restores.
    ///
    /// The bundle carries `[Profile]` inline, so it is the second
    /// reader of profile JSON — and backups shipped in v0.9.7
    /// itself. Missing the hop here refused the file as
    /// `.notABackup`, permanently: unlike a profile, a backup is
    /// never rewritten, so there is no next launch that repairs
    /// it (found in review, 2026-08-20).
    @MainActor
    @Test("A v0.9.7 backup is readable, not `.notABackup`")
    func retiredBackupIsReadable() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        var settings = TilingSettings()
        settings.appBarStyle.content = .iconAndTitle
        let bundle = SetupBundle(
            format: 1,
            writtenBy: "0.9.7",
            config: nil,
            profiles: [
                Profile(
                    name: "Starter",
                    monitorSets: [
                        MonitorSet(monitors: ["A:100x100"])
                    ],
                    spaceModes: [SpaceID(1): .monocle],
                    settings: settings
                )
            ],
            palettes: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let file = dir.appendingPathComponent("backup.json")
        try Data(
            String(
                decoding: try encoder.encode(bundle),
                as: UTF8.self
            )
            .replacingOccurrences(
                of: "\"icon_and_title\"",
                with: "\"icon_and_name\""
            ).utf8
        ).write(to: file)
        // The fixture must BE a v0.9.7 bundle.
        #expect(
            String(
                decoding: try Data(contentsOf: file),
                as: UTF8.self
            ).contains("icon_and_name")
        )

        let core = makeTestCore(configDirectory: dir)
        let read = try core.readBackup(at: file)
        #expect(read.profiles.count == 1)
        #expect(
            read.profiles.first?.settings.appBarStyle.content
                == .iconAndTitle
        )
    }

    /// A format-1 bundle stays readable after the bump — the
    /// refusal is for bundles from a NEWER build, never for the
    /// ones this crossing exists to accept.
    @Test("The format bump does not refuse v0.9.7 bundles")
    func formatBumpKeepsOldBundlesReadable() {
        #expect(
            SetupBundle(
                format: 1,
                writtenBy: "0.9.7",
                config: nil,
                profiles: [],
                palettes: []
            ).isReadable
        )
    }

    /// The migration touches ONE line of the file.
    ///
    /// It rewrites the user's config without being asked, so it
    /// may change only what it came for. Serializing the parsed
    /// tree back — the obvious implementation, and the one this
    /// shipped with first — re-encoded every `Double` in the
    /// file: `0.4` to `0.40000000000000002`, `0.6` to
    /// `0.59999999999999998`, five lines for a one-value change
    /// (measured, 2026-08-20). The decoded values were identical,
    /// which is exactly why no other test could see it, and why a
    /// config kept in a dotfiles repo would have shown the whole
    /// thing as noise.
    @MainActor
    @Test("Migrating rewrites only the line it came for")
    func migrationTouchesOneLine() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        var settings = TilingSettings()
        settings.appBarStyle.content = .iconAndTitle
        let manager = ProfileManager(directory: dir)
        try manager.save(
            Profile(
                name: "Starter",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [SpaceID(1): .monocle],
                settings: settings
            )
        )
        let file = dir.appendingPathComponent("Starter.json")
        let asWritten = String(
            decoding: try Data(contentsOf: file),
            as: UTF8.self
        )
        // The fixture must contain floats, or "one line changed"
        // is a claim about a file that never had any.
        #expect(asWritten.contains("0.4"))

        let old =
            asWritten
            .replacingOccurrences(
                of: "\"icon_and_title\"",
                with: "\"icon_and_name\""
            )
            .replacingOccurrences(
                of: "  \"format\" : 1,\n",
                with: ""
            )
        let migrated = String(
            decoding: try #require(
                ConfigMigration.migrated(Data(old.utf8))
            ),
            as: UTF8.self
        )
        let before = old.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let after = migrated.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        #expect(before.count == after.count)
        let changed = zip(before, after).filter { $0 != $1 }
        #expect(changed.count == 1)
        #expect(changed.first?.1.contains("icon_and_title") == true)
    }

    /// An unversioned legacy gui.json loads and decodes with current format.
    @Test("A legacy gui.json loads through GuiConfigStore")
    func guiConfigFileMigratesOnLoad() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GuiConfigStore(directory: dir)
        var config = GuiConfig()
        config.spaces = [SpaceID("code")]
        try store.save(config)
        let file = dir.appendingPathComponent("gui.json")
        let legacy = String(
            decoding: try Data(contentsOf: file),
            as: UTF8.self
        ).replacingOccurrences(
            of: "  \"format\" : 1,\n",
            with: ""
        )
        try legacy.write(to: file, atomically: true, encoding: .utf8)
        let loaded = store.load()
        #expect(loaded?.spaces == [SpaceID("code")])
        #expect(loaded?.format == GuiConfig.currentFormat)
    }
}
