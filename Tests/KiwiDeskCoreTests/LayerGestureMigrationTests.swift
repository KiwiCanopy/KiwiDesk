import Foundation
import Testing

@testable import KiwiDeskCore

/// Today's gesture map becomes the default layer's (#3535 ▸ Ruling
/// 2), once, at every reader of the three shapes: `gui.json`, a
/// profile file and a backup's `config` and `profiles[]`. Fixtures
/// are the encoder's own output: the old shape is `GestureMap`'s
/// encoding under `gesture`, re-stamped below each shape's floor.
@Suite("Layer gesture migration (#3535)")
struct LayerGestureMigrationTests {
    private var map: GestureMap {
        GestureMap([
            GestureKey(.tap3): .unbound,
            GestureKey(.swipe3, [.control, .option]):
                .bound(.family(.layout)),
        ])
    }

    /// `value`'s encoding with `gesture` written in the old one-map
    /// shape at `path` and the format re-stamped.
    private func oldShape<T: Encodable>(
        _ value: T,
        format: Int,
        at owner: (inout [String: Any], (inout [String: Any]) -> Void)
            -> Void = { root, edit in edit(&root) }
    ) throws -> Data {
        var root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(value)
            ) as? [String: Any]
        )
        let old = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(map)
        )
        owner(&root) { $0["gesture"] = old }
        root["format"] = format
        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private var profile: Profile {
        Profile(
            name: "Work",
            monitorSets: [],
            monitorCount: 1,
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    /// From the last release's stamp and from the one below the floor.
    @Test(
        "gui.json's map becomes the default layer's",
        arguments: [27, 28]
    )
    func guiCrosses(from format: Int) throws {
        let data = try oldShape(GuiConfig(), format: format)
        let out = try #require(ConfigMigration.migrated(data))
        let read = try JSONDecoder().decode(GuiConfig.self, from: out)
        #expect(read.gesture == LayerGestures(defaultLayer: map))
    }

    @Test("a profile's override becomes its default layer's")
    func profileCrosses() throws {
        let data = try oldShape(profile, format: 41)
        let out = try #require(ConfigMigration.migrated(data))
        let read = try JSONDecoder().decode(Profile.self, from: out)
        #expect(read.gesture == LayerGestures(defaultLayer: map))
    }

    @Test("a backup's config and profiles cross")
    func bundleCrosses() throws {
        let bundle = SetupBundle(
            format: 52,
            writtenBy: "test",
            config: GuiConfig(),
            profiles: [profile],
            palettes: []
        )
        let data = try oldShape(bundle, format: 52) { root, edit in
            var config = root["config"] as? [String: Any] ?? [:]
            edit(&config)
            root["config"] = config
            var profiles = root["profiles"] as? [[String: Any]] ?? []
            for index in profiles.indices { edit(&profiles[index]) }
            root["profiles"] = profiles
        }
        let out = try #require(ConfigMigration.migrated(data))
        let read = try JSONDecoder().decode(SetupBundle.self, from: out)
        #expect(read.config?.gesture == LayerGestures(defaultLayer: map))
        #expect(
            read.profiles.first?.gesture == LayerGestures(defaultLayer: map)
        )
    }

    /// A file at the new format is never re-wrapped: a layer named
    /// like a gesture would otherwise move under `default`.
    @Test("a current file stays as it is")
    func currentFileStays() throws {
        var config = GuiConfig()
        config.gesture = LayerGestures([
            "default": map, "Coding": map,
        ])
        let data = try JSONEncoder().encode(config)
        #expect(ConfigMigration.migratingGesturesOntoLayers(data) == nil)
        let read = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(read.gesture == config.gesture)
    }

    /// An empty old map carries no binding and stores nothing.
    @Test("an empty map leaves")
    func emptyMapLeaves() throws {
        var root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(GuiConfig())
            ) as? [String: Any]
        )
        root["gesture"] = [String: Any]()
        root["format"] = 28
        let data = try JSONSerialization.data(withJSONObject: root)
        let out = try #require(ConfigMigration.migrated(data))
        let read = try JSONDecoder().decode(GuiConfig.self, from: out)
        #expect(read.gesture.isEmpty)
    }
}
