import Foundation
import Testing

@testable import KiwiDeskCore

/// Which bar the shelf takes its values from, and what the file
/// meant where it stored nothing (#1517). The App Bar defaulted
/// to the BOTTOM edge before the shelf, whose default is the
/// top, so an App Bar source that never stored its edge owes the
/// shelf an explicit one — on BOTH paths, since the walk re-reads
/// the text edit and a disagreement drops to the re-encode.
@Suite("KiwiShelf migration: the source bar (#1517)")
struct KiwiShelfMigrationSourceTests {
    /// Pretty-printed like `ProfileManager.write`, with a float
    /// the walk's re-encode would rewrite (`0.40000000000000002`)
    /// — so reading `0.4` back proves the TEXT path answered.
    private static func profile(
        spaceBarEnabled: Bool,
        appBarEdge: String?
    ) -> Data {
        let edge = appBarEdge.map { "\"edge\" : \"\($0)\",\n" } ?? ""
        return Data(
            """
            {
              "format" : 7,
              "monitor_sets" : [

              ],
              "name" : "Work",
              "settings" : {
                "app_bar" : {
                  \(edge)"thickness" : 30
                },
                "space_bar" : {
                  "dim_factor" : 0.4,
                  "enabled" : \(spaceBarEnabled),
                  "thickness" : 44
                }
              }
            }
            """.utf8
        )
    }

    private func shelf(_ data: Data) throws -> [String: Any] {
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let settings = try #require(root["settings"] as? [String: Any])
        return try #require(settings["kiwishelf"] as? [String: Any])
    }

    @Test("a switched-off Space Bar yields to the App Bar, in place")
    func textPathTakesTheAppBar() throws {
        let data = Self.profile(spaceBarEnabled: false, appBarEdge: "left")
        let out = try #require(ConfigMigration.migrated(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(text.contains("\"dim_factor\" : 0.4,"))
        #expect(text.contains("\"kiwishelf\":{"))
        let shelf = try shelf(out)
        #expect(shelf["thickness"] as? Double == 30)
        #expect(shelf["edge"] as? String == "left")
    }

    @Test("an App Bar source with no edge keeps the bottom it sat on")
    func appBarSourceKeepsTheBottom() throws {
        let data = Self.profile(spaceBarEnabled: false, appBarEdge: nil)
        let out = try #require(ConfigMigration.migrated(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(text.contains("\"dim_factor\" : 0.4,"))
        #expect(try shelf(out)["edge"] as? String == "bottom")
    }

    /// The walk answers a bundle, whose several `settings` the
    /// text edit stands down on.
    @Test("the walk writes the App Bar's old bottom too")
    func walkKeepsTheBottom() throws {
        let data = Data(
            """
            {"format":11,"writtenBy":"KiwiDesk","config":{},\
            "profiles":[{"format":7,"monitor_sets":[],"name":"A",\
            "settings":{"app_bar":{"thickness":30},\
            "space_bar":{"enabled":false}}}]}
            """.utf8
        )
        let out = try #require(ConfigMigration.migrated(data))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        let settings = try #require(
            profiles.first?["settings"] as? [String: Any]
        )
        let shelf = try #require(settings["kiwishelf"] as? [String: Any])
        #expect(shelf["edge"] as? String == "bottom")
    }

    /// The Space Bar's old default edge IS the shelf's, so its
    /// silence carries over as silence.
    @Test("a Space Bar source with no edge writes none")
    func spaceBarSourceWritesNoEdge() throws {
        let data = Self.profile(spaceBarEnabled: true, appBarEdge: "left")
        let out = try #require(ConfigMigration.migrated(data))
        #expect(try shelf(out)["edge"] == nil)
        #expect(try shelf(out)["thickness"] as? Double == 44)
    }
}

/// The #1369 glass fill runs only on files written before the
/// default flip (#1517 review): at or above its floor an absent
/// leaf already MEANS the new default, which is every shelf-shaped
/// file — its bars hold no leaf and its shelf may be encoded
/// empty — so a later crossing must not fill them `false`.
@Suite("KiwiShelf migration: the glass floor (#1517)")
struct KiwiShelfGlassFloorTests {
    @Test("the glass fill stands down at the format it introduced")
    func standsDownAtItsFloor() {
        let atFloor = Data(
            """
            {"format":4,"monitor_sets":[],"name":"A",\
            "settings":{"space_bar":{"enabled":true}}}
            """.utf8
        )
        #expect(ConfigMigration.migratingAbsentGlassLeaves(atFloor) == nil)
        let bundle = Data(
            """
            {"format":6,"writtenBy":"KiwiDesk","config":{},\
            "profiles":[{"settings":{"space_bar":{}}}]}
            """.utf8
        )
        #expect(ConfigMigration.migratingAbsentGlassLeaves(bundle) == nil)
        let below = Data(
            """
            {"format":3,"monitor_sets":[],"name":"A",\
            "settings":{"space_bar":{"enabled":true}}}
            """.utf8
        )
        #expect(ConfigMigration.migratingAbsentGlassLeaves(below) != nil)
    }

    /// A sparse file between the floor and the crossing: no leaf
    /// anywhere means glass ON, and the shelf must say so by
    /// staying silent rather than inheriting a filled `false`.
    @Test("a sparse file past the floor crosses with glass on")
    func sparseFileKeepsGlassOn() throws {
        let data = Data(
            """
            {"format":7,"monitor_sets":[],"name":"A",\
            "settings":{"space_bar":{"thickness":44}}}
            """.utf8
        )
        let out = try #require(ConfigMigration.migrated(data))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let settings = try #require(root["settings"] as? [String: Any])
        let shelf = settings["kiwishelf"] as? [String: Any]
        #expect(shelf?["liquid_glass"] == nil)
        let spaceBar = settings["space_bar"] as? [String: Any]
        #expect(spaceBar?["liquid_glass"] == nil)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(withJSONObject: settings)
        )
        #expect(decoded.kiwishelf.liquidGlass)
    }
}
