import Foundation
import Testing

@testable import KiwiDeskCore

/// A stored app shortcut written before #1511 calls
/// `pull_or_spawn`; the crossing renames that one GUI-written shape
/// to `focus_or_spawn` in `gui.json`, a profile and a bundle, and
/// leaves any other Lua to fail loudly. Fixtures come from the
/// encoder, stamped at the format before the step.
@Suite("Focus or spawn migration (#1511)")
struct FocusOrSpawnMigrationTests {
    /// The formats before the step — spelled, so a bump cannot
    /// move the fixtures with it.
    private let guiBefore = 5
    private let profileBefore = 16
    private let bundleBefore = 21

    private static let old = "KiwiDesk.pull_or_spawn(\"com.apple.safari\")"
    private static let new = "KiwiDesk.focus_or_spawn(\"com.apple.safari\")"
    /// Hand-written Lua that merely starts like the stored shape.
    private static let script =
        "KiwiDesk.pull_or_spawn(\"com.a\"); KiwiDesk.focus(\"left\")"
    private static let spawn = "KiwiDesk.spawn_new(\"com.apple.terminal\")"

    private var rows: [KeyBinding] {
        [
            KeyBinding(
                combo: "control+option+s",
                lua: Self.old,
                kind: .application,
                label: ""
            ),
            KeyBinding(
                combo: "control+option+t",
                lua: Self.spawn,
                kind: .application,
                label: ""
            ),
            KeyBinding(
                combo: "control+option+f1",
                lua: Self.script,
                kind: .custom,
                label: ""
            ),
        ]
    }

    private var migratedRows: [String] { [Self.new, Self.spawn, Self.script] }

    private func guiConfig(format: Int) -> GuiConfig {
        var config = GuiConfig()
        config.format = format
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: rows)
        ]
        return config
    }

    private func profile(format: Int) -> Profile {
        Profile(
            format: format,
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings(),
            layers: KeyLayerOverride(
                layers: [
                    KeyLayer(name: KeyLayer.defaultName, bindings: rows)
                ]
            )
        )
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @Test("gui.json's app shortcut crosses, other Lua stays")
    func guiCrosses() throws {
        let data = try encoder.encode(guiConfig(format: guiBefore))
        let out = try #require(ConfigMigration.migrated(data))
        let config = try decoder.decode(GuiConfig.self, from: out)
        let layer = try #require(config.layers.first)
        #expect(layer.bindings.map(\.lua) == migratedRows)
        #expect(config.format == GuiConfig.currentFormat)
    }

    @Test("a profile's layer override crosses")
    func profileCrosses() throws {
        let data = try encoder.encode(profile(format: profileBefore))
        let out = try #require(ConfigMigration.migrated(data))
        let migrated = try decoder.decode(Profile.self, from: out)
        let layer = try #require(migrated.layers?.layers.first)
        #expect(layer.bindings.map(\.lua) == migratedRows)
    }

    @Test("a bundle's config and inline profiles cross")
    func bundleCrosses() throws {
        let bundle = SetupBundle(
            format: bundleBefore,
            writtenBy: "test",
            config: guiConfig(format: guiBefore),
            profiles: [profile(format: profileBefore)],
            palettes: []
        )
        let out = try #require(
            ConfigMigration.migrated(try encoder.encode(bundle))
        )
        let migrated = try decoder.decode(SetupBundle.self, from: out)
        let config = try #require(migrated.config?.layers.first)
        #expect(config.bindings.map(\.lua) == migratedRows)
        let inline = try #require(
            migrated.profiles.first?.layers?.layers.first
        )
        #expect(inline.bindings.map(\.lua) == migratedRows)
    }

    /// Unsorted keys, a four-space indent and `0.40` — what the
    /// re-encoder would change — so an exact match proves only the
    /// verb moved.
    @Test("the rename is surgical")
    func renameIsSurgical() throws {
        func file(_ verb: String) -> String {
            """
            {
                "ratio": 0.40,
                "layers": [ { "name": "default", "bindings": [
                    { "combo": "control+option+s", "kind": "application",
                      "lua": "KiwiDesk.\(verb)(\\"com.apple.safari\\")" }
                ] } ],
                "format": \(guiBefore)
            }
            """
        }
        let out = try #require(
            ConfigMigration.migratingRetiredPullOrSpawn(
                Data(file("pull_or_spawn").utf8)
            )
        )
        #expect(String(decoding: out, as: UTF8.self) == file("focus_or_spawn"))
    }

    @Test("only the exact stored shape is renamed")
    func onlyTheStoredShape() {
        #expect(
            ConfigMigration.renamedOpenOrFocusCall(Self.old) == Self.new
        )
        for lua in [
            Self.script,
            "KiwiDesk.pull_or_spawn(\"a\"b\")",
            "KiwiDesk.pull_or_spawn(\"\")",
            "KiwiDesk.pull_or_spawn( \"com.a\" )",
            Self.spawn,
        ] {
            #expect(
                ConfigMigration.renamedOpenOrFocusCall(lua) == nil,
                "\(lua)"
            )
        }
    }

    @Test("a file without the retired call is left alone")
    func untouchedWithoutTheCall() throws {
        var config = guiConfig(format: guiBefore)
        config.layers = []
        let data = try encoder.encode(config)
        #expect(ConfigMigration.migratingRetiredPullOrSpawn(data) == nil)
    }
}
