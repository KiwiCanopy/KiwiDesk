import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop base becomes the shortcut base (#2460): the retired
/// key's value is not carried — the seeded letters decide, once —
/// and a Go to Desktop row on `✦` + digit takes `✦⌥` + digit in
/// every stored layer. Fixtures come from the encoder, the retired
/// key spelled back in where the encoder no longer writes it.
@Suite("Shortcut base migration (#2460)")
struct ShortcutBaseMigrationTests {
    /// The formats before the step — spelled, so a change to the
    /// step's own constants cannot move the fixtures with them.
    private let guiBefore = 11
    private let profileBefore = 26

    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation, label: "")
    }

    private func desktop(_ combo: String, _ number: Int) -> KeyBinding {
        row(combo, "KiwiDesk.focus_desktop(\(number))")
    }

    /// Three seeded letters, `hyper` of them on Hyper.
    private func letters(onHyper hyper: Int) -> [KeyBinding] {
        let lua = [
            "KiwiDesk.toggle_floating()", "KiwiDesk.toggle_sticky()",
            "KiwiDesk.toggle_display_sticky()",
        ]
        let keys = ["f", "s", "p"]
        return (0..<3).map {
            row(
                ($0 < hyper ? "hyper+" : "control+option+") + keys[$0],
                lua[$0]
            )
        }
    }

    /// A pre-step `gui.json` with `rows` in its default layer and
    /// the retired key set to `old`.
    private func gui(_ rows: [KeyBinding], old: String) throws -> Data {
        var config = GuiConfig()
        config.format = guiBefore
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: rows)
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let text = String(decoding: try encoder.encode(config), as: UTF8.self)
            .replacingOccurrences(
                of: "\"shortcut_base\" : \"control+option\"",
                with: "\"desktop_shortcut_base\" : \"\(old)\""
            )
        #expect(text.contains("desktop_shortcut_base"))
        return Data(text.utf8)
    }

    private func decoded(_ data: Data) throws -> GuiConfig {
        try JSONDecoder().decode(GuiConfig.self, from: data)
    }

    @Test("letters on Hyper read as ✦, and the Desktop rows take ✦⌥")
    func movedInstallCrosses() throws {
        let rows =
            letters(onHyper: 2) + [
                desktop("hyper+1", 1), desktop("hyper+0", 10),
            ]
        let out = try #require(
            ConfigMigration.migrated(try gui(rows, old: "hyper"))
        )
        let config = try decoded(out)
        #expect(config.shortcutBase == .hyper)
        let combos = try #require(config.layers.first).bindings
            .filter { $0.lua.hasPrefix("KiwiDesk.focus_desktop") }
            .map(\.combo)
        #expect(combos == ["hyper+option+1", "hyper+option+0"])
    }

    @Test("letters on ⌃⌥ read as ⌃⌥, whatever the Desktop base was")
    func unmovedInstallStays() throws {
        for old in ["hyper", "control+option+shift+command"] {
            let rows =
                letters(onHyper: 1) + [
                    desktop("control+option+shift+command+2", 2)
                ]
            let out = try #require(
                ConfigMigration.migrated(try gui(rows, old: old))
            )
            let config = try decoded(out)
            #expect(config.shortcutBase == .standard)
            #expect(
                try #require(config.layers.first).bindings.last?.combo
                    == "control+option+shift+command+2"
            )
        }
    }

    /// Only a Go to Desktop row on exactly `✦` + digit moves: the
    /// Space digits take `✦` + digit under the new base.
    @Test("only a Desktop row on bare ✦ + digit moves")
    func onlyBareHyperDesktopRowsMove() throws {
        let rows = [
            desktop("hyper+shift+3", 3),
            row("hyper+4", "KiwiDesk.focus_space(\"4\")"),
            desktop("hyper+f5", 5),
        ]
        let out = try #require(
            ConfigMigration.migrated(try gui(rows, old: "hyper"))
        )
        #expect(
            try #require(try decoded(out).layers.first).bindings
                .map(\.combo) == rows.map(\.combo)
        )
    }

    @Test("a profile's layer override crosses too")
    func profileOverrideCrosses() throws {
        let profile = Profile(
            format: profileBefore,
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings(),
            layers: KeyLayerOverride(
                layers: [
                    KeyLayer(
                        name: KeyLayer.defaultName,
                        bindings: [desktop("hyper+2", 2)]
                    )
                ]
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let out = try #require(
            ConfigMigration.migrated(try encoder.encode(profile))
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let migrated = try decoder.decode(Profile.self, from: out)
        let bindings = try #require(migrated.layers?.layers.first)
            .bindings
        #expect(bindings.map(\.combo) == ["hyper+option+2"])
    }

    @Test("a bundle's config and its profiles cross")
    func bundleCrosses() throws {
        let rows: [[String: Any]] = [
            [
                "combo": "hyper+f", "kind": "navigation",
                "lua": "KiwiDesk.toggle_floating()",
            ],
            [
                "combo": "hyper+1", "kind": "navigation",
                "lua": "KiwiDesk.focus_desktop(1)",
            ],
        ]
        let layers: [[String: Any]] = [
            ["name": "default", "bindings": rows]
        ]
        let root: [String: Any] = [
            SetupBundle.shapeMarker: 1,
            "format": ConfigMigration.shortcutBaseBundleFormat - 1,
            "config": [
                "desktop_shortcut_base": "hyper", "layers": layers,
            ],
            "profiles": [["layers": ["layers": layers]]],
        ]
        let out = try #require(
            ConfigMigration.migratingShortcutBase(
                try JSONSerialization.data(withJSONObject: root)
            )
        )
        let text = String(decoding: out, as: UTF8.self)
        #expect(!text.contains("desktop_shortcut_base"))
        #expect(text.contains("\"shortcut_base\":\"hyper\""))
        #expect(!text.contains("\"hyper+1\""))
        #expect(
            text.components(separatedBy: "\"hyper+option+1\"").count == 3
        )
    }

    /// Unsorted keys, odd spacing and `0.40` — what the re-encoder
    /// would change — so an exact match proves only the two edits
    /// touched the file.
    @Test("the rewrite is surgical")
    func rewriteIsSurgical() throws {
        func file(_ base: String, _ combo: String) -> String {
            """
            {
                "ratio": 0.40,
                "\(base)",
                "layers": [ { "name": "default", "bindings": [
                    { "lua": "KiwiDesk.focus_desktop(3)",
                      "combo":   "\(combo)", "kind": "navigation" }
                ] } ],
                "format": \(guiBefore)
            }
            """
        }
        let before = file(
            #"desktop_shortcut_base": "control+option+shift+command"#,
            "hyper+3"
        )
        let out = try #require(
            ConfigMigration.migratingShortcutBase(Data(before.utf8))
        )
        let after = file(
            #"shortcut_base": "control+option"#,
            "hyper+option+3"
        )
        #expect(String(decoding: out, as: UTF8.self) == after)
    }

    /// A meaning change: at its own format the step stands down,
    /// or a `✦3` the user records for a Desktop later moves again.
    @Test("each shape stands down at its own floor")
    func floorsArePerShape() throws {
        let layers: [[String: Any]] = [
            [
                "name": "default",
                "bindings": [
                    [
                        "combo": "hyper+3", "kind": "navigation",
                        "lua": "KiwiDesk.focus_desktop(3)",
                    ]
                ],
            ]
        ]
        let gui: [String: Any] = ["layers": layers]
        let profile: [String: Any] = [
            "monitor_sets": [], "layers": ["layers": layers],
        ]
        let bundle: [String: Any] = [
            SetupBundle.shapeMarker: 1, "config": gui,
        ]
        let cases: [([String: Any], Int)] = [
            (gui, ConfigMigration.shortcutBaseGuiFormat),
            (profile, ConfigMigration.shortcutBaseProfileFormat),
            (bundle, ConfigMigration.shortcutBaseBundleFormat),
        ]
        for (root, floor) in cases {
            var at = root
            at["format"] = floor
            var below = root
            below["format"] = floor - 1
            let step = ConfigMigration.migratingShortcutBase
            #expect(
                step(try JSONSerialization.data(withJSONObject: at)) == nil
            )
            #expect(
                step(try JSONSerialization.data(withJSONObject: below))
                    != nil
            )
        }
    }
}
