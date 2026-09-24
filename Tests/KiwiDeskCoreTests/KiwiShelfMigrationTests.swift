import Foundation
import Testing

@testable import KiwiDeskCore

/// The bars' crossing onto the shelf (#1517): a file below the
/// floor keeps what it showed — the Space Bar's shared values
/// become the shelf's (the App Bar's where the Space Bar is off),
/// the other copies drop, `item_size` drops everywhere and the
/// Space Bar's `title_cap` becomes `front_app_title_cap`. Without
/// it the retired keys decode to nothing and a customised bar
/// silently snaps back to the defaults.
@Suite("KiwiShelf migration (#1517)")
struct KiwiShelfMigrationTests {
    /// A profile as `ProfileManager.write` lays one out —
    /// pretty-printed, sorted keys — at the format before the
    /// crossing, carrying the pre-2.0 bar keys this build no
    /// longer encodes. Every Liquid Glass leaf is present, as a
    /// 1.x encoder writes it, so the #1369 fill has nothing to do.
    private static let preShelfProfile = """
        {
          "format" : 7,
          "monitor_sets" : [

          ],
          "name" : "Work",
          "settings" : {
            "app_bar" : {
              "content" : "icon",
              "edge" : "bottom",
              "item_color" : "#EAF3EE",
              "item_size" : 120,
              "liquid_glass" : true,
              "thickness" : 30
            },
            "layout" : {
              "monocle" : {
                "app_bar" : {
                  "content" : "title",
                  "edge" : "left",
                  "enabled" : true,
                  "thickness" : 50
                }
              }
            },
            "shortcut_panel" : {
              "liquid_glass" : false
            },
            "space_bar" : {
              "active_dim_factor" : 0.4,
              "active_indicator" : "gap",
              "edge" : "left",
              "fill_color" : "#112233B3",
              "item_color" : "#EAF3EE66",
              "item_gap" : 3,
              "liquid_glass" : false,
              "thickness" : 36,
              "title_cap" : 24
            }
          }
        }
        """

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
    }

    private func settings(_ data: Data) throws -> [String: Any] {
        try #require(root(data)["settings"] as? [String: Any])
    }

    private func group(
        _ object: [String: Any],
        _ key: String
    ) -> [String: Any]? {
        object[key] as? [String: Any]
    }

    @Test("the Space Bar's shared values become the shelf's")
    func spaceBarValuesMove() throws {
        let data = Data(Self.preShelfProfile.utf8)
        let out = try #require(ConfigMigration.migrated(data))
        let s = try settings(out)
        let shelf = try #require(group(s, "kiwishelf"))
        #expect(shelf["edge"] as? String == "left")
        #expect(shelf["thickness"] as? Double == 36)
        #expect(shelf["item_gap"] as? Double == 3)
        #expect(shelf["liquid_glass"] as? Bool == false)
        let space = try #require(group(s, "space_bar"))
        #expect(space["edge"] == nil)
        #expect(space["thickness"] == nil)
        #expect(space["title_cap"] == nil)
        #expect(space["front_app_title_cap"] as? Double == 24)
        #expect(space["active_dim_factor"] as? Double == 0.4)
        // Colours move too; the Space Bar's dimmed idle ink is the
        // App Bar's colour at a lower alpha, so the shelf takes the
        // full colour and the idle rule dims it.
        #expect(shelf["fill_color"] as? String == "#112233B3")
        #expect(shelf["item_color"] as? String == "#EAF3EE")
        #expect(space["fill_color"] == nil)
        #expect(space["item_color"] == nil)
        // Gap is gone; the App Bar that named none keeps Outline
        // ahead of its default's flip.
        #expect(space["active_indicator"] as? String == "outline")
        let app = try #require(group(s, "app_bar"))
        #expect(app["edge"] == nil)
        #expect(app["thickness"] == nil)
        #expect(app["item_size"] == nil)
        #expect(app["content"] as? String == "icon")
        #expect(app["item_color"] == nil)
        #expect(app["active_indicator"] as? String == "outline")
        #expect(try root(out)["format"] as? Int == Profile.currentFormat)
    }

    @Test("a layout's shared overrides drop, its own stay")
    func layoutOverridesDrop() throws {
        let data = Data(Self.preShelfProfile.utf8)
        let out = try #require(ConfigMigration.migrated(data))
        let layout = try #require(group(try settings(out), "layout"))
        let monocle = try #require(group(layout, "monocle"))
        let bar = try #require(group(monocle, "app_bar"))
        #expect(bar["edge"] == nil)
        #expect(bar["thickness"] == nil)
        #expect(bar["content"] as? String == "title")
        #expect(bar["enabled"] as? Bool == true)
    }

    /// The bar the user actually saw: with the Space Bar off,
    /// the App Bar's placement is what the shelf must keep.
    @Test("a switched-off Space Bar yields to the App Bar")
    func spaceBarOffYields() throws {
        let data = Data(
            """
            {"format":7,"monitor_sets":[],"name":"A",\
            "settings":{"app_bar":{"edge":"bottom","thickness":30},\
            "space_bar":{"enabled":false,"edge":"top","thickness":44}}}
            """.utf8
        )
        let out = try #require(ConfigMigration.migrated(data))
        let shelf = try #require(group(try settings(out), "kiwishelf"))
        #expect(shelf["edge"] as? String == "bottom")
        #expect(shelf["thickness"] as? Double == 30)
    }

    /// The textual edit is what keeps a user's file theirs: the
    /// walk's re-serialization rewrites every Double
    /// (`0.40000000000000002`), which the surgical path exists to
    /// avoid. Read off the TEXT, since a re-parse cannot tell.
    @Test("a profile file is edited in place, not re-encoded")
    func textualEditKeepsBytes() throws {
        let data = Data(Self.preShelfProfile.utf8)
        let out = try #require(ConfigMigration.migrated(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(text.contains("\"active_dim_factor\" : 0.4,"))
        #expect(text.contains("\"kiwishelf\":{"))
        #expect(!text.contains("0.40000"))
    }

    @Test("the migrated file decodes to the shelf it describes")
    func decodesAfterwards() throws {
        let data = Data(Self.preShelfProfile.utf8)
        let out = try #require(ConfigMigration.migrated(data))
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(
                withJSONObject: try settings(out)
            )
        )
        #expect(decoded.kiwishelf.edge == .left)
        #expect(decoded.kiwishelf.thickness == 36)
        #expect(decoded.kiwishelf.liquidGlass == false)
        #expect(decoded.spaceBarStyle.frontAppTitleCap == 24)
        #expect(decoded.appBarStyle.content == .icon)
    }

    @Test("a migrated file needs no second crossing")
    func crossingEnds() throws {
        let data = Data(Self.preShelfProfile.utf8)
        let out = try #require(ConfigMigration.migrated(data))
        #expect(ConfigMigration.migrated(out) == nil)
        #expect(ConfigMigration.migratingBarsOntoShelf(out) == nil)
    }

    /// A bundle carries `[Profile]` inline, each with its own
    /// settings; the text edit stands down on more than one
    /// `settings` object, so this is the walk's path.
    @Test("each inline profile of a bundle crosses on its own")
    func bundleProfilesCross() throws {
        let data = Data(
            """
            {"format":11,"writtenBy":"KiwiDesk","config":{},\
            "profiles":[\
            {"name":"A","settings":{"space_bar":{"edge":"left"}}},\
            {"name":"B","settings":{"space_bar":{"edge":"right"}}}]}
            """.utf8
        )
        let out = try #require(ConfigMigration.migrated(data))
        let profiles = try #require(
            try root(out)["profiles"] as? [[String: Any]]
        )
        let edges = profiles.map {
            (($0["settings"] as? [String: Any])?["kiwishelf"]
                as? [String: Any])?["edge"] as? String
        }
        #expect(edges == ["left", "right"])
        #expect(
            try root(out)["format"] as? Int
                == SetupBundle.currentFormat
        )
    }
}
