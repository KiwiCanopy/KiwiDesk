import Foundation
import Testing

@testable import KiwiDeskCore

/// Each bar takes its edge back from the shelf (#1731): a stored
/// `kiwishelf.edge` becomes both bars' edge, so every setup lands
/// fused where it was, and the key drops.
@Suite("Bar edge migration (#1731)")
struct BarEdgeMigrationTests {
    /// Real encoder output with the shelf's retired edge put back.
    private func legacySettings(edge: String?) throws -> [String: Any] {
        let data = try JSONEncoder().encode(TilingSettings())
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var shelf = try #require(settings["kiwishelf"] as? [String: Any])
        shelf["edge"] = edge
        settings["kiwishelf"] = shelf
        for group in ["space_bar", "app_bar"] {
            var bar = try #require(settings[group] as? [String: Any])
            bar["edge"] = nil
            settings[group] = bar
        }
        return settings
    }

    /// A profile root stamped at the format before this step.
    private func profile(edge: String?, format: Int = 10) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": format,
                "monitor_sets": [String: Any](),
                "settings": legacySettings(edge: edge),
            ],
            options: [.prettyPrinted]
        )
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    @Test("the shelf's edge becomes both bars' and drops")
    func edgeMovesToBothBars() throws {
        let out = try #require(
            ConfigMigration.migrated(profile(edge: "left"))
        )
        let settings = try #require(root(out)["settings"] as? [String: Any])
        let shelf = try #require(settings["kiwishelf"] as? [String: Any])
        #expect(shelf["edge"] == nil)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(withJSONObject: settings)
        )
        #expect(decoded.spaceBarStyle.edge == .left)
        #expect(decoded.appBarStyle.edge == .left)
        #expect(decoded.sharedBarEdge == .left)
    }

    @Test("an absent edge has nothing to move")
    func absentEdgeIsLeft() throws {
        #expect(
            ConfigMigration.migratingShelfEdgeOntoBars(
                try profile(edge: nil)
            ) == nil
        )
    }

    @Test("the step stands down at the format it introduced")
    func standsDownAtItsFormat() throws {
        #expect(
            ConfigMigration.migratingShelfEdgeOntoBars(
                try profile(edge: "left", format: 11)
            ) == nil
        )
    }

    @Test("a bar that states an edge keeps it")
    func statedBarEdgeWins() throws {
        var settings = try legacySettings(edge: "left")
        var app = try #require(settings["app_bar"] as? [String: Any])
        app["edge"] = "bottom"
        settings["app_bar"] = app
        let (moved, changed) = ConfigMigration.barEdgedSettings(settings)
        #expect(changed)
        let space = try #require(moved["space_bar"] as? [String: Any])
        let movedApp = try #require(moved["app_bar"] as? [String: Any])
        #expect(space["edge"] as? String == "left")
        #expect(movedApp["edge"] as? String == "bottom")
    }

    @Test("a bundle's inline profiles cross too")
    func bundleProfilesCross() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": 14,
                SetupBundle.shapeMarker: "test",
                "profiles": [
                    ["name": "A", "settings": legacySettings(edge: "right")]
                ],
            ]
        )
        let out = try #require(
            ConfigMigration.migratingShelfEdgeOntoBars(bundle)
        )
        let profiles = try #require(root(out)["profiles"] as? [[String: Any]])
        let settings = try #require(
            profiles.first?["settings"] as? [String: Any]
        )
        let space = try #require(settings["space_bar"] as? [String: Any])
        let app = try #require(settings["app_bar"] as? [String: Any])
        #expect(space["edge"] as? String == "right")
        #expect(app["edge"] as? String == "right")
    }

    /// A 1.x file (before the shelf) crosses both steps in one
    /// read: each bar keeps the edge it sat on, the App Bar its
    /// old bottom where it stored none, so a split setup stays
    /// split — while a 2.0 file's one edge lands fused.
    @Test(
        "a setup split before the shelf stays split",
        arguments: [#""edge" : "left","#, ""]
    )
    func preShelfSplitStaysSplit(appEdge: String) throws {
        let text = """
            {
              "format" : 7,
              "monitor_sets" : [],
              "name" : "Old",
              "settings" : {
                "app_bar" : {
                  \(appEdge)
                  "thickness" : 30
                },
                "space_bar" : {
                  "edge" : "top",
                  "thickness" : 44
                }
              }
            }
            """
        let out = try #require(ConfigMigration.migrated(Data(text.utf8)))
        let settings = try #require(root(out)["settings"] as? [String: Any])
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(withJSONObject: settings)
        )
        #expect(decoded.spaceBarStyle.edge == .top)
        #expect(
            decoded.appBarStyle.edge == (appEdge.isEmpty ? .bottom : .left)
        )
        #expect(decoded.sharedBarEdge == nil)
        let shelf = settings["kiwishelf"] as? [String: Any]
        #expect(shelf?["edge"] == nil)
    }

    /// A file missing a bar group stands the textual edit down to
    /// the walk, which creates the group — never a trap.
    @Test("a missing bar group falls back to the walk")
    func missingGroupTakesTheWalk() throws {
        let text = """
            {
              "format": 10,
              "monitor_sets": {},
              "settings": {
                "kiwishelf": {"edge": "right"},
                "space_bar": {"enabled": true}
              }
            }
            """
        let out = try #require(
            ConfigMigration.migratingShelfEdgeOntoBars(Data(text.utf8))
        )
        let settings = try #require(root(out)["settings"] as? [String: Any])
        let app = try #require(settings["app_bar"] as? [String: Any])
        let space = try #require(settings["space_bar"] as? [String: Any])
        #expect(app["edge"] as? String == "right")
        #expect(space["edge"] as? String == "right")
    }

    /// The textual edit keeps every other byte: a double is not
    /// re-encoded, and a layout's App Bar gets no edge of its own.
    @Test("the edit is surgical")
    func editIsSurgical() throws {
        let text = """
            {
              "format": 10,
              "monitor_sets": {},
              "settings": {
                "kiwishelf": {
                  "thickness": 40, "edge": "bottom", "minimum": 0.4
                },
                "space_bar": {"enabled": true},
                "app_bar": {},
                "layout": {"monocle": {"app_bar": {"enabled": true}}}
              }
            }
            """
        let out = try #require(
            ConfigMigration.migratingShelfEdgeOntoBars(Data(text.utf8))
        )
        let edited = try #require(String(data: out, encoding: .utf8))
        #expect(edited.contains("\"minimum\": 0.4"))
        #expect(edited.contains("\"space_bar\": {\"edge\":\"bottom\","))
        #expect(edited.contains("\"app_bar\": {\"edge\":\"bottom\"}"))
        #expect(edited.contains("\"app_bar\": {\"enabled\": true}"))
        #expect(!edited.contains("\"edge\": \"bottom\""))
    }
}
