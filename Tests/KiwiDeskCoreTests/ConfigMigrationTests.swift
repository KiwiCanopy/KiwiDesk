import Foundation
import Testing

@testable import KiwiDeskCore

/// The one-shot crossing for configs written by v0.9.7 or
/// earlier, where `app_bar.content` still read `name` /
/// `icon_and_name`.
///
/// The decode is strict, so without this the value does not
/// degrade — it takes its whole FILE down, and the file is a
/// profile: `allProfiles()` skips one it cannot read, so the
/// profile disappears from the list (surfaced as a
/// `ConfigIssue.profileBroken`, with Delete / Reveal).
///
/// Every profile v0.9.7 wrote carries the value, because
/// `TilingSettings.encode` is exhaustive and `.iconAndName` was
/// that build's DEFAULT — so this is not the narrow case of
/// users who changed the setting. `gui.json` is untouched by it:
/// `GuiConfig.encode` never writes `settings`, so the sidecar
/// cannot hold a bar-content value at all.
@Suite("Retired bar content migration")
struct ConfigMigrationTests {
    private func json(_ raw: String) -> Data { Data(raw.utf8) }

    /// The pair actually shipped, and the pair a real config
    /// carries.
    @Test("Both retired spellings are rewritten")
    func bothSpellingsMigrate() throws {
        for (retired, expected) in [
            ("name", "title"),
            ("icon_and_name", "icon_and_title"),
        ] {
            let data = json(
                """
                {"settings":{"app_bar":{"content":"\(retired)"}}}
                """
            )
            let out = try #require(
                ConfigMigration.migratingRetiredBarContent(data)
            )
            let root =
                try JSONSerialization.jsonObject(with: out)
                as? [String: Any]
            let settings = root?["settings"] as? [String: Any]
            let bar = settings?["app_bar"] as? [String: Any]
            #expect(bar?["content"] as? String == expected)
        }
    }

    /// A per-layout override carries the same vocabulary at a
    /// different depth, which is why the walk rewrites by KEY
    /// rather than down a hardcoded path — a migration that
    /// reached only the global style would leave the file just
    /// as undecodable.
    @Test("A per-layout override migrates too")
    func layoutOverrideMigrates() throws {
        let data = json(
            """
            {"settings":{"monocle":{"app_bar":\
            {"content":"icon_and_name"}}}}
            """
        )
        let out = try #require(
            ConfigMigration.migratingRetiredBarContent(data)
        )
        let text = String(decoding: out, as: UTF8.self)
        #expect(text.contains("icon_and_title"))
        #expect(!text.contains("icon_and_name"))
    }

    /// Nil, not the same bytes: the callers write back exactly
    /// when this returns non-nil, so a config with nothing to do
    /// must never have its file rewritten.
    @Test("A current config is left alone")
    func currentConfigIsUntouched() {
        let data = json(
            """
            {"settings":{"app_bar":{"content":"icon_and_title"}}}
            """
        )
        #expect(
            ConfigMigration.migratingRetiredBarContent(data)
                == nil
        )
    }

    /// The common case: sparse configs never wrote the key.
    @Test("A config with no content key is left alone")
    func absentKeyIsUntouched() {
        let data = json(#"{"settings":{"app_bar":{"edge":"top"}}}"#)
        #expect(
            ConfigMigration.migratingRetiredBarContent(data)
                == nil
        )
    }

    /// `name` is a common word in this config — the profile's own
    /// name, a space's, an app rule's. Only a `content` value may
    /// be rewritten, or the migration corrupts what it touches.
    @Test("A `name` FIELD is never rewritten")
    func unrelatedNameFieldSurvives() {
        let data = json(
            """
            {"name":"name","app_rules":{"Finder":"name"},\
            "settings":{"app_bar":{"content":"icon_and_title"}}}
            """
        )
        #expect(
            ConfigMigration.migratingRetiredBarContent(data)
                == nil
        )
    }

    /// Running twice changes nothing the second time — the
    /// property the best-effort write-back depends on, since a
    /// read-only config directory makes every launch retry.
    @Test("The migration is idempotent")
    func migrationIsIdempotent() throws {
        let data = json(
            """
            {"settings":{"app_bar":{"content":"name"}}}
            """
        )
        let once = try #require(
            ConfigMigration.migratingRetiredBarContent(data)
        )
        #expect(
            ConfigMigration.migratingRetiredBarContent(once)
                == nil
        )
    }

    /// The end-to-end claim, in the shape the user meets it: a
    /// v0.9.7 profile decodes again.
    ///
    /// Built by ENCODING a real profile and then downgrading the
    /// one value, rather than hand-writing the JSON: the fixture
    /// then carries whatever shape `Profile` currently requires,
    /// so this cannot rot into testing a file no build ever
    /// wrote.
    @Test("A v0.9.7 profile decodes after migrating")
    func retiredProfileDecodes() throws {
        var settings = TilingSettings()
        settings.appBarStyle.content = .iconAndTitle
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let current = try encoder.encode(
            Profile(
                name: "Starter",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [SpaceID(1): .monocle],
                settings: settings
            )
        )
        // ...as v0.9.7 would have written it.
        let old = Data(
            String(decoding: current, as: UTF8.self)
                .replacingOccurrences(
                    of: "\"icon_and_title\"",
                    with: "\"icon_and_name\""
                ).utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(throws: DecodingError.self) {
            try decoder.decode(Profile.self, from: old)
        }

        let migrated = try #require(
            ConfigMigration.migratingRetiredBarContent(old)
        )
        let profile = try decoder.decode(
            Profile.self,
            from: migrated
        )
        // The whole VALUE, not two fields: the function rewrites
        // the entire file through a `JSONSerialization` round
        // trip, so anything it quietly changed elsewhere — a
        // number's representation, an escape, a dropped key —
        // belongs in the net. `Profile` is `Equatable`, so the
        // net costs one line.
        let original = try decoder.decode(
            Profile.self,
            from: current
        )
        #expect(profile == original)
        #expect(
            profile.settings.appBarStyle.content == .iconAndTitle
        )
    }

    // MARK: - The production wiring

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
        #expect(SetupBundle.currentFormat == 2)
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
}
