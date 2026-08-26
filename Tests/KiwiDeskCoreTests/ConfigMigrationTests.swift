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
                ConfigMigration.migrated(data)
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
            ConfigMigration.migrated(data)
        )
        let text = String(decoding: out, as: UTF8.self)
        #expect(text.contains("icon_and_title"))
        #expect(!text.contains("icon_and_name"))
    }

    /// Nil, not the same bytes: the callers write back exactly
    /// when this returns non-nil, so a config with nothing to do
    /// must never have its file rewritten. Since the #945 stamp
    /// fix, "nothing to do" requires the format to be current —
    /// an unversioned file is stamped even with current values
    /// (`unversionedFileWithNothingToRewriteIsStamped`).
    @Test("A current config is left alone")
    func currentConfigIsUntouched() {
        let data = json(
            """
            {"format":\(GuiConfig.currentFormat),\
            "settings":{"app_bar":{"content":"icon_and_title"}}}
            """
        )
        #expect(
            ConfigMigration.migrated(data)
                == nil
        )
    }

    /// The common case: sparse configs never wrote the key.
    @Test("A stamped config with no content key is left alone")
    func absentKeyIsUntouched() {
        let data = json(
            """
            {"format":\(GuiConfig.currentFormat),\
            "settings":{"app_bar":{"edge":"top"}}}
            """
        )
        #expect(
            ConfigMigration.migrated(data)
                == nil
        )
    }

    /// `name` is a common word in this config — the profile's own
    /// name, a space's, an app rule's. Only a `content` value may
    /// be rewritten, or the migration corrupts what it touches.
    /// The fixture stays UNVERSIONED so the walk actually runs
    /// (a current-format fixture would skip it and assert
    /// nothing); the stamp is then the only permitted change.
    @Test("A `name` FIELD is never rewritten")
    func unrelatedNameFieldSurvives() throws {
        let data = json(
            """
            {"name":"name","app_rules":{"Finder":"name"},\
            "settings":{"app_bar":{"content":"icon_and_title"}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let root =
            try JSONSerialization.jsonObject(with: out)
            as? [String: Any]
        #expect(root?["name"] as? String == "name")
        let rules = root?["app_rules"] as? [String: Any]
        #expect(rules?["Finder"] as? String == "name")
        #expect(root?["format"] as? Int == GuiConfig.currentFormat)
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
            ConfigMigration.migrated(data)
        )
        #expect(
            ConfigMigration.migrated(once)
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
                format: 0,
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
            ConfigMigration.migrated(old)
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

    /// A config already carrying the CURRENT format skips
    /// migration immediately without scanning payload.
    ///
    /// The number is derived, not spelled: the claim is about a
    /// file at whatever this build writes, which stays true across
    /// every bump, while a literal reds on each one and guards
    /// nothing (tests.md, #1021). This fixture has no
    /// `monitor_sets`, so `targetFormat` routes it as a
    /// `GuiConfig` — the shape whose current format it must carry.
    @Test("A current-format config skips migration")
    func currentFormatSkipsMigration() {
        let data = json(
            """
            {"format":\(GuiConfig.currentFormat),"settings":\
            {"app_bar":{"content":"icon_and_title"}}}
            """
        )
        #expect(ConfigMigration.migrated(data) == nil)
    }

    /// A profile carrying a newer format than supported is refused.
    @Test("A profile with newer format is refused")
    func newerProfileFormatIsRefused() throws {
        let future = Profile.currentFormat + 1
        let data = json(
            """
            {"format":\(future),"name":"Future","monitor_sets":\
            [{"monitors":["A:100x100"]}],"space_modes":{"1":"bsp"},\
            "settings":{}}
            """
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(throws: DecodingError.self) {
            try decoder.decode(Profile.self, from: data)
        }
    }

    /// A GuiConfig carrying a newer format than supported is refused.
    @Test("A GuiConfig with newer format is refused")
    func newerGuiConfigFormatIsRefused() {
        let future = GuiConfig.currentFormat + 1
        let data = json(
            """
            {"format":\(future),"spaces":["1"]}
            """
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(GuiConfig.self, from: data)
        }
    }
}
