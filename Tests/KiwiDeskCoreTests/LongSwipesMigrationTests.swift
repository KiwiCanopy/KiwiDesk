import Foundation
import Testing

@testable import KiwiDeskCore

/// A stored `long_swipes: false` in the scroll-gesture base turns on
/// (#1873 ▸ owner ruling 2026-11-15), in `gui.json` and a backup's
/// `config`, from the format the last release (4.2.1) stamped; a
/// profile's sparse override keeps its own. Fixtures are the
/// encoder's own output.
@Suite("Long swipes migration (#1873)")
struct LongSwipesMigrationTests {
    private var config: GuiConfig {
        var config = GuiConfig()
        config.scrollGesture.longSwipes = false
        config.scrollGesture.stepLength = 7.25
        return config
    }

    private var profile: Profile {
        Profile(
            name: "Work",
            monitorSets: [],
            spaceModes: [:],
            settings: TilingSettings(),
            scrollGesture: ScrollGestureOverride(longSwipes: false)
        )
    }

    private func stamped<T: Encodable>(
        _ value: T,
        format: Int
    ) throws -> Data {
        var root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(value)
            ) as? [String: Any]
        )
        root["format"] = format
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
        #expect(
            String(decoding: data, as: UTF8.self)
                .contains("\"long_swipes\" : false")
        )
        return data
    }

    private func bundle(format: Int) throws -> Data {
        try stamped(
            SetupBundle(
                format: format,
                writtenBy: "test",
                config: config,
                profiles: [profile],
                palettes: []
            ),
            format: format
        )
    }

    /// From 4.2.1's stamp (19), so every later step runs ahead of
    /// this one, and from the format below this step's (26).
    @Test("gui.json turns long swipes on", arguments: [19, 26])
    func guiCrosses(from format: Int) throws {
        let data = try stamped(config, format: format)
        let out = try #require(ConfigMigration.migrated(data))
        let read = try JSONDecoder().decode(GuiConfig.self, from: out)
        #expect(read.scrollGesture.longSwipes)
        #expect(read.scrollGesture.stepLength == 7.25)
    }

    /// From 4.2.1's backup stamp (43) and from 50: the base turns on,
    /// the profile's own off stays.
    @Test(
        "a backup's config turns on, its profile's stays",
        arguments: [43, 50]
    )
    func bundleCrosses(from format: Int) throws {
        let out = try #require(
            ConfigMigration.migrated(bundle(format: format))
        )
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let inner = try JSONSerialization.data(
            withJSONObject: #require(root["config"])
        )
        let read = try JSONDecoder().decode(GuiConfig.self, from: inner)
        #expect(read.scrollGesture.longSwipes)
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        let own = profiles.first?["scroll_gesture"] as? [String: Any]
        #expect(own?["long_swipes"] as? Bool == false)
    }

    /// The edit rewrites the one literal and leaves every other byte.
    @Test("the edit is surgical")
    func editIsSurgical() throws {
        // A spacing the walk's re-serialization would not keep, so
        // the migration's answer tells the edit from the walk.
        let text = String(
            decoding: try stamped(config, format: 26),
            as: UTF8.self
        )
        .replacingOccurrences(of: "\"format\" : ", with: "\"format\" :  ")
        let data = Data(text.utf8)
        let edited = try #require(ConfigMigration.longSwipesTextOn(text))
        let out = String(decoding: edited, as: UTF8.self)
        #expect(out.contains("\"long_swipes\" : true"))
        #expect(out.count == text.count - 1)
        #expect(ConfigMigration.migratingLongSwipesOn(data) == edited)
    }

    /// At the formats it introduced the step stands down, so a
    /// false written after the crossing is the user's.
    @Test("the step stands down at its own formats")
    func standsDown() throws {
        let gui = try stamped(
            config,
            format: ConfigMigration.longSwipesGuiFormat
        )
        #expect(ConfigMigration.migratingLongSwipesOn(gui) == nil)
        let data = try bundle(format: ConfigMigration.longSwipesBundleFormat)
        #expect(ConfigMigration.migratingLongSwipesOn(data) == nil)
    }

    /// A profile file is never reached: its false is a choice.
    @Test("a profile file keeps its own off")
    func profileKept() throws {
        let data = try stamped(profile, format: 30)
        #expect(ConfigMigration.migratingLongSwipesOn(data) == nil)
    }
}
