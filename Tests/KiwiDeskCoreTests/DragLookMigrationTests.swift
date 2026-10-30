import Foundation
import Testing

@testable import KiwiDeskCore

/// The drag markers' look retires (#2797): the colour, fill, border
/// and alignment knobs leave `drag.ghost` and `drag.drop_zone`, and
/// the four palette paths leave every colour map, in every shape a
/// file takes — a profile, `gui.json`, a backup, `palettes.json`,
/// `looks.json` — each crossing from the format the last release
/// stamped. Settings fixtures are the encoder's own output with the
/// retired keys put back.
@Suite("Drag look migration (#2797)")
struct DragLookMigrationTests {
    private static var knobs: [String: Any] {
        [
            "border": true, "border_color": "#347957",
            "border_alignment": "outside", "fill": true,
            "fill_color": "#34795740",
        ]
    }

    private static let colors: [String: String] = [
        "drag.ghost.border_color": "#347957",
        "drag.ghost.fill_color": "#34795740",
        "drag.drop_zone.border_color": "#C2790A",
        "drag.drop_zone.fill_color": "#C2790A40",
        "border.focused_color": "#4A9816",
    ]

    /// Encoder output with every knob put back on both markers,
    /// the ghost stored on as a saved profile holds it.
    private func legacySettings() throws -> [String: Any] {
        let data = try JSONEncoder().encode(TilingSettings())
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var drag = try #require(settings["drag"] as? [String: Any])
        for marker in ["ghost", "drop_zone"] {
            var visual = try #require(drag[marker] as? [String: Any])
            visual.merge(Self.knobs) { _, new in new }
            visual["enabled"] = true
            drag[marker] = visual
        }
        settings["drag"] = drag
        return settings
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    /// Whether a retired palette path or the alignment knob, which
    /// no other setting spells, survives in the bytes.
    private func mentionsRetired(_ data: Data) -> Bool {
        let text = String(decoding: data, as: UTF8.self)
        return text.contains("\"drag.")
            || text.contains("\"border_alignment\"")
    }

    @Test("a profile keeps only each marker's switch")
    func profileCrosses() throws {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 32,
                "monitor_sets": [String: Any](),
                "settings": legacySettings(),
            ],
            options: [.prettyPrinted, .sortedKeys]
        )
        let out = try #require(ConfigMigration.migrated(data))
        #expect(!mentionsRetired(out))
        let migrated = try root(out)
        #expect(migrated["format"] as? Int == Profile.currentFormat)
        let settings = try #require(migrated["settings"] as? [String: Any])
        let drag = try #require(settings["drag"] as? [String: Any])
        for marker in ["ghost", "drop_zone"] {
            let visual = try #require(drag[marker] as? [String: Any])
            #expect(Set(visual.keys) == ["enabled"], "\(marker)")
            // A saved switch is kept: no migration of values.
            #expect(visual["enabled"] as? Bool == true, "\(marker)")
        }
        // Everything else the file held survives the crossing.
        let border = try #require(settings["border"] as? [String: Any])
        #expect(border["enabled"] != nil)
    }

    @Test("gui.json's shared look loses the drag colours")
    func guiConfigCrosses() throws {
        let gui = try JSONSerialization.data(
            withJSONObject: [
                "format": 17,
                "look": ["colors": Self.colors],
            ]
        )
        let out = try #require(ConfigMigration.migrated(gui))
        #expect(!mentionsRetired(out))
        let migrated = try root(out)
        #expect(migrated["format"] as? Int == GuiConfig.currentFormat)
        let look = try #require(migrated["look"] as? [String: Any])
        let colors = try #require(look["colors"] as? [String: String])
        #expect(colors == ["border.focused_color": "#4A9816"])
    }

    @Test("a backup's profiles, palettes and looks cross")
    func bundleCrosses() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": 41,
                SetupBundle.shapeMarker: "test",
                "profiles": [
                    [
                        "format": 32,
                        "name": "A",
                        "monitor_sets": [String: Any](),
                        "settings": legacySettings(),
                    ]
                ],
                "palettes": [["name": "P", "colors": Self.colors]],
                "looks": [["name": "L", "colors": Self.colors]],
            ]
        )
        let out = try #require(ConfigMigration.migrated(bundle))
        #expect(!mentionsRetired(out))
        #expect(
            try root(out)["format"] as? Int == SetupBundle.currentFormat
        )
    }

    @Test("palettes.json and looks.json drop the paths")
    func librariesCross() throws {
        for key in ["palettes", "looks"] {
            let data = try JSONSerialization.data(
                withJSONObject: [
                    "format": 2,
                    key: [["name": "P", "colors": Self.colors]],
                ]
            )
            let out = try #require(ConfigMigration.migrated(data), "\(key)")
            #expect(!mentionsRetired(out), "\(key)")
            let migrated = try root(out)
            let entries = try #require(migrated[key] as? [[String: Any]])
            let colors = entries.first?["colors"] as? [String: String]
            #expect(colors == ["border.focused_color": "#4A9816"])
        }
        let palettes = try root(
            try #require(
                ConfigMigration.migrated(
                    JSONSerialization.data(
                        withJSONObject: ["format": 2, "palettes": []]
                    )
                )
            )
        )
        #expect(palettes["format"] as? Int == PaletteDocument.currentFormat)
    }

    /// A shared look exported before the retirement crosses in
    /// memory on import, since the file is never rewritten.
    @Test("an exported look crosses on import")
    func lookExportCrosses() throws {
        let data = try JSONSerialization.data(
            withJSONObject: ["name": "L", "colors": Self.colors]
        )
        let out = ConfigMigration.crossingLookExport(data, from: 2)
        #expect(!mentionsRetired(out))
    }

    /// The textual edit itself: only a direct call tells it from
    /// the tree fallback.
    @Test("the drop removes only the retired lines")
    func dropIsSurgical() throws {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 32,
                "monitor_sets": [String: Any](),
                "settings": legacySettings(),
                "look": ["colors": Self.colors],
            ],
            options: [.prettyPrinted, .sortedKeys]
        )
        let out = try #require(
            ConfigMigration.surgicallyDroppedDragLook(
                String(decoding: data, as: UTF8.self)
            )
        )
        let lines = { (data: Data) in
            String(decoding: data, as: UTF8.self)
                .split(separator: "\n", omittingEmptySubsequences: false)
        }
        // Each marker's knobs and every drag palette path.
        let paths = Self.colors.keys.filter { $0.hasPrefix("drag.") }
        #expect(
            lines(data).count - lines(out).count
                == 2 * Self.knobs.count + paths.count
        )
        #expect(!mentionsRetired(out))
        // The kiwishelf's own `border` switch is no marker's knob.
        let edited = try root(out)
        let settings = try #require(edited["settings"] as? [String: Any])
        let shelf = try #require(settings["kiwishelf"] as? [String: Any])
        #expect(shelf["border"] != nil)
    }

    /// Not idempotent by construction — the walk ignores depth — so
    /// it stands down at the formats it introduced (#1354's shape).
    @Test("the step stands down at its own floors")
    func standsDownAtTheFloor() throws {
        let floors: [(key: String, format: Int, extra: [String: Any])] = [
            (
                "settings", ConfigMigration.dragLookProfileFormat,
                ["monitor_sets": [String: Any]()]
            ),
            ("settings", ConfigMigration.dragLookGuiFormat, [:]),
        ]
        for floor in floors {
            var root = floor.extra
            root["format"] = floor.format
            root[floor.key] = try legacySettings()
            let data = try JSONSerialization.data(withJSONObject: root)
            #expect(ConfigMigration.migratingRetiredDragLook(data) == nil)
            root["format"] = floor.format - 1
            let below = try JSONSerialization.data(withJSONObject: root)
            #expect(ConfigMigration.migratingRetiredDragLook(below) != nil)
        }
        for (key, format) in [
            ("palettes", ConfigMigration.dragLookPaletteFormat),
            ("looks", ConfigMigration.dragLookLookFormat),
        ] {
            let data = try JSONSerialization.data(
                withJSONObject: [
                    "format": format,
                    key: [["name": "P", "colors": Self.colors]],
                ]
            )
            #expect(ConfigMigration.migratingRetiredDragLook(data) == nil)
        }
    }

    @Test("a file without the retired keys is left alone")
    func untouchedWithoutTheKeys() throws {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 32,
                "monitor_sets": [String: Any](),
                "settings": try JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(TilingSettings())
                ),
            ]
        )
        #expect(ConfigMigration.migratingRetiredDragLook(data) == nil)
    }
}
