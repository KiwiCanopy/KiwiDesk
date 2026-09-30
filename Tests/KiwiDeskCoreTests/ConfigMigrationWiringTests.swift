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

    /// The `format` line the CURRENT writer emits, derived rather
    /// than spelled.
    ///
    /// A fixture here simulates an unversioned legacy file by
    /// STRIPPING that line out of one this build just wrote. Spell
    /// the number and the strip silently stops matching the day the
    /// format bumps — the fixture is then a current-format file,
    /// `needsMigration` short-circuits, and the test fails for a
    /// reason that has nothing to do with what it guards. That is
    /// exactly what the #1020 bump did to three of these
    /// (tests.md: pin the shape a decision has, never the value it
    /// resolves to today).
    private func stamp(_ format: Int) -> String {
        "  \"format\" : \(format),\n"
    }

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

    /// `text` with a retired `app_bar.content` entry put back as
    /// the first line of every `app_bar` object — the pretty,
    /// sorted layout `ProfileManager` writes, so the fixture is
    /// this build's own output plus the one key an older build
    /// wrote.
    private func withRetiredContent(_ text: String) -> String {
        text.replacingOccurrences(
            of: "(\"app_bar\" : \\{\\n)( *)",
            with: "$1$2\"content\" : \"icon_and_name\",\n$2",
            options: .regularExpression
        )
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
        let manager = ProfileManager(directory: dir)
        try manager.save(
            Profile(
                name: "Starter",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [SpaceID(1): .monocle],
                settings: TilingSettings()
            )
        )
        let file = dir.appendingPathComponent("Starter.json")
        try Data(
            withRetiredContent(
                String(
                    decoding: try Data(contentsOf: file),
                    as: UTF8.self
                )
            )
            .replacingOccurrences(
                of: stamp(Profile.currentFormat),
                with: ""
            ).utf8
        ).write(to: file)

        #expect(
            String(
                decoding: try Data(contentsOf: file),
                as: UTF8.self
            ).contains("icon_and_name")
        )

        _ = try manager.read(name: "Starter")
        // Repaired in place, so the crossing runs once rather
        // than on every launch forever.
        let onDisk = String(
            decoding: try Data(contentsOf: file),
            as: UTF8.self
        )
        #expect(!onDisk.contains("icon_and_name"))
        #expect(onDisk.contains(stamp(Profile.currentFormat)))
        #expect(manager.allProfiles().map(\.name) == ["Starter"])
    }

    /// A BACKUP from an older build restores with its values.
    ///
    /// The bundle carries `[Profile]` inline, so it is the second
    /// reader of profile JSON — and backups shipped in v0.9.7
    /// itself. Missing the hop here refused the file as
    /// `.notABackup`, permanently: unlike a profile, a backup is
    /// never rewritten, so there is no next launch that repairs
    /// it (found in review, 2026-08-20). The fixture carries a
    /// renamed key (#1528's `glyph_cap`), whose value the decode
    /// drops without the hop, so the hop is what this observes.
    @MainActor
    @Test("An older backup is readable, its values intact")
    func retiredBackupIsReadable() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        var settings = TilingSettings()
        settings.spaceBarStyle.glyphSpan = 8
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
                of: "\"glyph_span\"",
                with: "\"glyph_cap\""
            ).utf8
        ).write(to: file)
        // The fixture must BE an older bundle.
        #expect(
            String(
                decoding: try Data(contentsOf: file),
                as: UTF8.self
            ).contains("glyph_cap")
        )

        let core = makeTestCore(configDirectory: dir)
        let read = try core.readBackup(at: file)
        #expect(read.profiles.count == 1)
        #expect(
            read.profiles.first?.settings.spaceBarStyle.glyphSpan == 8
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

    /// The migration touches only what it came for.
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
    @Test("Migrating rewrites only the migrated keys and stamp")
    func migrationTouchesOneLine() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = ProfileManager(directory: dir)
        try manager.save(
            Profile(
                name: "Starter",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [SpaceID(1): .monocle],
                settings: TilingSettings()
            )
        )
        let file = dir.appendingPathComponent("Starter.json")
        let asWritten = String(
            decoding: try Data(contentsOf: file),
            as: UTF8.self
        )
        // The fixture must contain floats, or the claim that floats
        // are untouched is a claim about a file that never had any.
        #expect(asWritten.contains("0.4"))

        // A format-0 v0.9.7 profile: the retired App Bar content,
        // and the track limit one below today's — what that build
        // stored for the picture today's default draws (#1354's
        // lift).
        let downgradedLimit = asWritten.replacingOccurrences(
            of: "\"limit\" : \(TrackParams().limit)",
            with: "\"limit\" : \(TrackParams().limit - 1)"
        )
        #expect(downgradedLimit != asWritten)
        let old = withRetiredContent(downgradedLimit)
            .replacingOccurrences(
                of: stamp(Profile.currentFormat),
                with: stamp(0)
            )
        #expect(old.contains("icon_and_name"))
        let migrated = String(
            decoding: try #require(
                ConfigMigration.migrated(Data(old.utf8))
            ),
            as: UTF8.self
        )
        // Floats remain un-reencoded:
        #expect(migrated.contains("0.4"))
        #expect(!migrated.contains("0.40000000000000002"))
        #expect(!migrated.contains("icon_and_name"))

        // The content lines are gone; of the rest exactly two
        // change: the stamp and the lifted track limit.
        let before = old.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .filter { !$0.contains("\"content\"") }
        // A pre-#1752 profile gains its `look: own` line (#1752),
        // envelope like the stamp, set aside before the count.
        let after = migrated.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .filter { $0 != #"  "look" : "own","# }
        #expect(before.count == after.count)
        let changed = zip(before, after).filter { $0 != $1 }
        #expect(changed.count == 2)
        #expect(
            changed.contains {
                $0.1.contains("\"limit\" : \(TrackParams().limit)")
            }
        )
        #expect(
            changed.contains {
                $0.1.contains(
                    "\"format\" : \(Profile.currentFormat)"
                )
            }
        )
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
            of: stamp(GuiConfig.currentFormat),
            with: ""
        )
        try legacy.write(to: file, atomically: true, encoding: .utf8)
        let loaded = store.load()
        #expect(loaded?.spaces == [SpaceID("code")])
        #expect(loaded?.format == GuiConfig.currentFormat)
    }
}
