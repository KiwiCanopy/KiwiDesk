import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar's grouping defaults off (#1725), and a profile
/// saved before the setting existed keeps the grouping it always
/// had (owner ruling 2026-09-29). Fixtures are the encoder's own
/// output with the new key taken out, never hand-typed JSON.
@Suite("Space Bar grouping migration (#1725)")
struct SpaceBarGroupingMigrationTests {
    /// Real encoder output as a build before #1725 wrote it: the
    /// Space Bar carries no `group_adjacent_windows`.
    private func legacySettings() throws -> [String: Any] {
        let data = try JSONEncoder().encode(TilingSettings())
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var bar = try #require(settings["space_bar"] as? [String: Any])
        #expect(bar["group_adjacent_windows"] != nil)
        bar["group_adjacent_windows"] = nil
        settings["space_bar"] = bar
        return settings
    }

    private func profile(
        _ settings: [String: Any],
        format: Int = 13
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": format,
                "monitor_sets": [String: Any](),
                "settings": settings,
            ],
            options: [.prettyPrinted]
        )
    }

    private func grouping(in settings: Any?) throws -> Bool {
        let data = try JSONSerialization.data(
            withJSONObject: try #require(settings)
        )
        return try JSONDecoder().decode(TilingSettings.self, from: data)
            .spaceBarStyle.groupAdjacentWindows
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    @Test("a fresh setup draws one glyph per window")
    func defaultIsOff() {
        #expect(!SpaceBarStyle().groupAdjacentWindows)
    }

    @Test("a profile from before keeps its grouping")
    func legacyProfileKeepsGrouping() throws {
        let out = try #require(
            ConfigMigration.migrated(profile(legacySettings()))
        )
        let migrated = try root(out)
        #expect(try grouping(in: migrated["settings"]))
        #expect(migrated["format"] as? Int == Profile.currentFormat)
    }

    @Test("the edit touches only the Space Bar")
    func surgicalEditKeepsTheRest() throws {
        let data = try profile(legacySettings())
        let out = try #require(
            ConfigMigration.migratingSpaceBarGrouping(data)
        )
        let before = try #require(String(data: data, encoding: .utf8))
        let after = try #require(String(data: out, encoding: .utf8))
        // The App Bar's own key is not the Space Bar's: its
        // count is unchanged and one more occurrence was written.
        let needle = "\"group_adjacent_windows\""
        #expect(
            after.components(separatedBy: needle).count
                == before.components(separatedBy: needle).count + 1
        )
        #expect(after.count > before.count)
        #expect(
            after.replacingOccurrences(
                of: "\"group_adjacent_windows\":true,",
                with: ""
            ) == before
        )
    }

    /// A settings root with no Space Bar takes the whole object,
    /// inserted in place: an exact match against the input with
    /// the insert removed proves nothing else moved.
    @Test("a settings root with no Space Bar gains one in place")
    func missingSpaceBarIsInserted() throws {
        let text = """
            {
                "settings": { "ratio": 0.40 },
                "monitor_sets": {},
                "format": 13
            }
            """
        let out = try #require(
            ConfigMigration.surgicallyFilledGrouping(text)
        )
        let after = String(decoding: out, as: UTF8.self)
        let insert =
            "\"space_bar\":{\"group_adjacent_windows\":true},"
        #expect(after.replacingOccurrences(of: insert, with: "") == text)
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        #expect(try grouping(in: root["settings"]))
    }

    @Test("an explicit choice is kept")
    func explicitValueKept() throws {
        var settings = try legacySettings()
        var bar = try #require(settings["space_bar"] as? [String: Any])
        bar["group_adjacent_windows"] = false
        settings["space_bar"] = bar
        let data = try profile(settings)
        #expect(ConfigMigration.migratingSpaceBarGrouping(data) == nil)
    }

    @Test("a file written after the flip is left alone")
    func currentFormatUntouched() throws {
        let data = try profile(
            legacySettings(),
            format: ConfigMigration.groupingProfileFormat
        )
        #expect(ConfigMigration.migratingSpaceBarGrouping(data) == nil)
    }

    @Test("a backup's inline profiles cross too")
    func bundleProfilesCross() throws {
        let inline: [String: Any] = [
            "format": 13,
            "name": "A",
            "monitor_sets": [String: Any](),
            "settings": try legacySettings(),
        ]
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": 18,
                SetupBundle.shapeMarker: "test",
                "profiles": [inline, inline],
            ]
        )
        let out = try #require(ConfigMigration.migrated(bundle))
        let profiles = try #require(
            root(out)["profiles"] as? [[String: Any]]
        )
        #expect(profiles.count == 2)
        for profile in profiles {
            #expect(try grouping(in: profile["settings"]))
        }
    }
}
