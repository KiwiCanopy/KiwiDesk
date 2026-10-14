import Foundation
import Testing

@testable import KiwiDeskCore

/// A stored panel shortcut written before #2265 calls one of the
/// three `show_*` verbs; the crossing renames those exact calls to
/// `kiwihub.show` in `gui.json`, a profile and a bundle, and leaves
/// any other Lua to fail loudly. Fixtures come from the encoder,
/// stamped at the format before the step.
@Suite("KiwiHub migration (#2265)")
struct KiwiHubMigrationTests {
    /// The formats before the step — spelled, so a bump cannot
    /// move the fixtures with it.
    private let guiBefore = 6
    private let profileBefore = 20
    private let bundleBefore = 25

    /// Hand-written Lua that merely starts like a stored call.
    private static let script =
        "KiwiDesk.show_shortcuts(); KiwiDesk.focus(\"left\")"

    private var rows: [KeyBinding] {
        [
            row("j", "KiwiDesk.show_jump_to_window()"),
            row("k", "KiwiDesk.show_shortcuts()"),
            row("l", "KiwiDesk.show_layout_picker()"),
            row("f1", Self.script, kind: .custom),
        ]
    }

    private var migratedRows: [String] {
        KiwiHubSide.allCases.map(\.lua) + [Self.script]
    }

    private func row(
        _ key: String,
        _ lua: String,
        kind: KeyBinding.Kind = .navigation
    ) -> KeyBinding {
        KeyBinding(
            combo: "control+option+\(key)",
            lua: lua,
            kind: kind,
            label: ""
        )
    }

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

    @Test("gui.json's panel shortcuts cross, other Lua stays")
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
    /// call moved.
    @Test("the rename is surgical")
    func renameIsSurgical() throws {
        func file(_ lua: String) -> String {
            """
            {
                "ratio": 0.40,
                "layers": [ { "name": "default", "bindings": [
                    { "combo": "control+option+k", "kind": "navigation",
                      "lua": "\(lua)" }
                ] } ],
                "format": \(guiBefore)
            }
            """
        }
        let out = try #require(
            ConfigMigration.migratingRetiredPanelVerbs(
                Data(file("KiwiDesk.show_shortcuts()").utf8)
            )
        )
        #expect(
            String(decoding: out, as: UTF8.self)
                == file("kiwihub.show(\\\"shortcuts\\\")")
        )
    }

    @Test("a file without a retired call is left alone")
    func untouchedWithoutTheCall() throws {
        var config = guiConfig(format: guiBefore)
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [row("f1", Self.script, kind: .custom)]
            )
        ]
        let data = try encoder.encode(config)
        #expect(ConfigMigration.migratingRetiredPanelVerbs(data) == nil)
    }
}
