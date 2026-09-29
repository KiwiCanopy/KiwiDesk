import Foundation
import Testing

@testable import KiwiDeskCore

/// A stored layer written before #1797 loses a Space verb's extra
/// navigation chords — the #485 top-up's leftovers — keeping the
/// Space's own digit, else the first; a `custom` row is drawn as
/// its own row and stays. Fixtures come
/// from the encoder, stamped at the format before the step.
@Suite("Duplicate Space chord migration (#1797)")
struct DuplicateSpaceChordMigrationTests {
    /// The formats before the step — spelled, so a change to the
    /// step's own constants cannot move the fixtures with them.
    private let guiBefore = 4
    private let profileBefore = 14

    private func row(
        _ combo: String,
        _ lua: String,
        kind: KeyBinding.Kind = .navigation
    ) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: kind, label: "")
    }

    private func follow(_ space: String) -> String {
        "KiwiDesk.move_to_space_and_follow(\"\(space)\")"
    }

    /// The owner's default layer: Space 1 on ⌃⌥⌘5 and ⌃⌥⌘1 — the
    /// extra FIRST, so keeping the own digit is told apart from
    /// keeping the first — and Space 5 on ⌃⌥⌘6 alone.
    private var ownersRows: [KeyBinding] {
        [
            row("control+option+command+5", follow("1")),
            row("control+option+command+1", follow("1")),
            row("control+option+command+6", follow("5")),
        ]
    }

    private func gui(_ bindings: [KeyBinding]) throws -> Data {
        var config = GuiConfig()
        config.format = guiBefore
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: bindings)
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(config)
    }

    private func layer(_ data: Data) throws -> [KeyBinding] {
        let config = try JSONDecoder().decode(GuiConfig.self, from: data)
        return try #require(config.layers.first).bindings
    }

    @Test("a Space's second chord is dropped, its own digit kept")
    func ownDigitIsKept() throws {
        let out = try #require(
            ConfigMigration.migrated(try gui(ownersRows))
        )
        let combos = try layer(out).map(\.combo)
        #expect(
            combos == [
                "control+option+command+1",
                "control+option+command+6",
            ]
        )
    }

    @Test("the tenth Space's own digit is 0")
    func tenthKeepsZero() throws {
        let rows = [
            row("control+option+command+9", follow("10")),
            row("control+option+command+0", follow("10")),
        ]
        let out = try #require(ConfigMigration.migrated(try gui(rows)))
        #expect(
            try layer(out).map(\.combo) == ["control+option+command+0"]
        )
    }

    @Test("without an own digit the first chord is kept")
    func firstIsKeptOtherwise() throws {
        let rows = [
            row("control+option+f2", follow("Mail")),
            row("control+option+f3", follow("Mail")),
        ]
        let out = try #require(ConfigMigration.migrated(try gui(rows)))
        #expect(try layer(out).map(\.combo) == ["control+option+f2"])
    }

    @Test("a custom row and a different verb are left alone")
    func customAndOtherVerbsStay() throws {
        let rows = [
            row("control+option+1", "KiwiDesk.focus_space(\"1\")"),
            row(
                "control+option+f1",
                "KiwiDesk.focus_space(1)",
                kind: .custom
            ),
            row("control+option+shift+1", "KiwiDesk.move_to_space(\"1\")"),
        ]
        let out = try #require(ConfigMigration.migrated(try gui(rows)))
        #expect(try layer(out).count == 3)
    }

    @Test("a profile's layer override crosses too")
    func profileOverrideCrosses() throws {
        let profile = Profile(
            format: profileBefore,
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings(),
            layers: KeyLayerOverride(
                layers: [
                    KeyLayer(
                        name: KeyLayer.defaultName,
                        bindings: ownersRows
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
        #expect(
            bindings.map(\.combo) == [
                "control+option+command+1",
                "control+option+command+6",
            ]
        )
    }

    /// Four-space indent, unsorted keys and `0.40` — what the
    /// re-encoder would change — so an exact match proves only the
    /// dropped row left the file.
    @Test("the drop is surgical")
    func dropIsSurgical() throws {
        let keep = """
            { "combo": "control+option+1", "kind": "navigation",
                      "lua": "KiwiDesk.focus_space(\\"1\\")" }
            """
        let extra = """
            { "combo": "control+option+5", "kind": "navigation",
                      "lua": "KiwiDesk.focus_space(\\"1\\")" }
            """
        func file(_ rows: String) -> String {
            """
            {
                "spaces": ["1"],
                "ratio": 0.40,
                "layers": [ { "name": "default", "bindings": [
                    \(rows)
                ] } ],
                "format": \(guiBefore)
            }
            """
        }
        let before = file(keep + ",\n        " + extra)
        let out = try #require(
            ConfigMigration.migratingDuplicateSpaceChords(
                Data(before.utf8)
            )
        )
        #expect(String(decoding: out, as: UTF8.self) == file(keep))
    }

    @Test("each shape stands down at its own floor")
    func floorsArePerShape() throws {
        let bindings: [[String: Any]] = ownersRows.map {
            ["combo": $0.combo, "lua": $0.lua, "kind": "navigation"]
        }
        let layers: [[String: Any]] = [
            ["name": "default", "bindings": bindings]
        ]
        func data(_ root: [String: Any]) throws -> Data {
            try JSONSerialization.data(withJSONObject: root)
        }
        let profile: [String: Any] = [
            "monitor_sets": [], "layers": ["layers": layers],
        ]
        let bundle: [String: Any] = [
            SetupBundle.shapeMarker: 1, "config": ["layers": layers],
        ]
        let cases: [([String: Any], Int)] = [
            (profile, ConfigMigration.spaceChordProfileFormat),
            (bundle, ConfigMigration.spaceChordBundleFormat),
        ]
        for (root, floor) in cases {
            var at = root
            at["format"] = floor
            var below = root
            below["format"] = floor - 1
            #expect(
                ConfigMigration.migratingDuplicateSpaceChords(
                    try data(at)
                ) == nil
            )
            #expect(
                ConfigMigration.migratingDuplicateSpaceChords(
                    try data(below)
                ) != nil
            )
        }
    }

    @Test("a file already at the step's format is not touched")
    func currentFormatStandsDown() throws {
        var config = GuiConfig()
        config.format = ConfigMigration.spaceChordGuiFormat
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: ownersRows)
        ]
        let data = try JSONEncoder().encode(config)
        #expect(
            ConfigMigration.migratingDuplicateSpaceChords(data) == nil
        )
    }
}
