import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket's edge and position move onto KiwiShelf (#2678): a
/// 4.0.0 `pocket.edge` / `pocket.position` lands as
/// `kiwishelf.pocket_edge` / `pocket_position`, so an update keeps
/// where the user put the pocket.
@Suite("Pocket placement migration (#2678)")
struct PocketPlacementMigrationTests {
    /// Real encoder output with 4.0.0's pocket keys put back and the
    /// shelf's new ones taken out.
    private func legacySettings(
        edge: String?,
        position: Double?
    ) throws -> [String: Any] {
        let data = try JSONEncoder().encode(TilingSettings())
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var shelf = try #require(settings["kiwishelf"] as? [String: Any])
        shelf["pocket_edge"] = nil
        shelf["pocket_position"] = nil
        settings["kiwishelf"] = shelf
        var pocket = settings["pocket"] as? [String: Any] ?? [:]
        pocket["edge"] = edge
        pocket["position"] = position
        settings["pocket"] = pocket
        return settings
    }

    private func profile(
        edge: String?,
        position: Double?,
        format: Int = 31
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": format,
                "monitor_sets": [String: Any](),
                "settings": legacySettings(edge: edge, position: position),
            ],
            options: [.prettyPrinted]
        )
    }

    private func decoded(_ data: Data) throws -> TilingSettings {
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let settings = try #require(root["settings"] as? [String: Any])
        return try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(withJSONObject: settings)
        )
    }

    @Test("4.0.0's edge and position land on the shelf")
    func placementMovesToShelf() throws {
        let out = try #require(
            ConfigMigration.migrated(
                profile(edge: "left", position: 30)
            )
        )
        let settings = try decoded(out)
        #expect(settings.kiwishelf.pocketEdge == .left)
        #expect(settings.kiwishelf.pocketPosition == 30)
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\"position\""))
    }

    @Test("the textual edit keeps the rest of the file's bytes")
    func surgicalEditTouchesOnlyThePair() throws {
        let data = try profile(edge: "top", position: 12.5)
        let out = try #require(
            ConfigMigration.migratingPocketPlacementOntoShelf(data)
        )
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(text.contains("\"pocket_edge\":\"top\""))
        #expect(text.contains("\"pocket_position\":12.5"))
    }

    @Test("an edge alone moves alone")
    func edgeAloneMoves() throws {
        let out = try #require(
            ConfigMigration.migratingPocketPlacementOntoShelf(
                profile(edge: "right", position: nil)
            )
        )
        let settings = try decoded(out)
        #expect(settings.kiwishelf.pocketEdge == .right)
        #expect(
            settings.kiwishelf.pocketPosition
                == KiwiShelf().pocketPosition
        )
    }

    @Test("a profile with no placement has nothing to move")
    func absentPlacementIsLeft() throws {
        #expect(
            ConfigMigration.migratingPocketPlacementOntoShelf(
                try profile(edge: nil, position: nil)
            ) == nil
        )
    }

    @Test("the step stands down at the format it introduced")
    func standsDownAtItsFormat() throws {
        #expect(
            ConfigMigration.migratingPocketPlacementOntoShelf(
                try profile(edge: "left", position: 30, format: 32)
            ) == nil
        )
    }

    @Test("a bundle's inline profiles move through the pipeline")
    func bundleProfilesMove() throws {
        let settings = try legacySettings(edge: "left", position: 5)
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                SetupBundle.shapeMarker: true,
                "format": 40,
                "profiles": [["settings": settings]],
            ]
        )
        let out = try #require(ConfigMigration.migrated(bundle))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let format = try #require(root["format"] as? Int)
        #expect(format >= ConfigMigration.pocketPlacementBundleFormat)
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        let shelf = try #require(
            (profiles.first?["settings"] as? [String: Any])?["kiwishelf"]
                as? [String: Any]
        )
        #expect(shelf["pocket_edge"] as? String == "left")
        #expect(shelf["pocket_position"] as? Double == 5)
    }
}
