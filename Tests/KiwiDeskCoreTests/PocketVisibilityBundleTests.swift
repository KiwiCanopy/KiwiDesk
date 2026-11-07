import Foundation
import Testing

@testable import KiwiDeskCore

/// A bundle crosses the retired pocket capacity into its own
/// profiles in one `ConfigMigration` step, by its format (#2978).
@Suite("Pocket visibility bundle crossing (#2978)")
struct PocketVisibilityBundleTests {
    private func settings(
        space: ShelfVisibility,
        app: ShelfVisibility,
        pocket edge: AppBarEdge = .top
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.spaceBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = space
        for mode in LayoutMode.allCases {
            settings.setAppBarVisibility(app, in: mode)
        }
        settings.kiwishelf.pocketEdge = edge
        return settings
    }

    @Test("a bundle crosses its config's capacity into its profiles")
    func bundleStep() throws {
        var stated = TilingSettings()
        stated.kiwishelf.pocketVisibility = .hidden
        func object(_ settings: TilingSettings) throws -> Any {
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(settings)
            )
        }
        var hidden = try #require(
            try object(settings(space: .hidden, app: .hidden))
                as? [String: Any]
        )
        var shelf = try #require(hidden["kiwishelf"] as? [String: Any])
        shelf["pocket_visibility"] = nil
        hidden["kiwishelf"] = shelf
        let root: [String: Any] = [
            "format": 42,
            "writtenBy": "test",
            "config": ["pocket": ["capacity": "several"]],
            "profiles": [
                ["settings": hidden],
                ["settings": try object(stated)],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: root)
        let out = try #require(
            ConfigMigration.migratingPocketCapacityOntoShelf(data)
        )
        let crossed = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let config = try #require(crossed["config"] as? [String: Any])
        #expect(config["pocket"] == nil)
        let profiles = try #require(
            crossed["profiles"] as? [[String: Any]]
        )
        let values = profiles.map {
            (($0["settings"] as? [String: Any])?["kiwishelf"]
                as? [String: Any])?["pocket_visibility"] as? String
        }
        #expect(values == ["auto", "hidden"])
    }

    /// A format-42 bundle's profile after `ConfigMigration.migrated`,
    /// with `config` as given.
    private func crossedBundle(config: [String: Any]?) throws -> String? {
        var settings = try #require(
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    self.settings(space: .always, app: .always)
                )
            ) as? [String: Any]
        )
        var shelf = try #require(settings["kiwishelf"] as? [String: Any])
        shelf["pocket_visibility"] = nil
        settings["kiwishelf"] = shelf
        var root: [String: Any] = [
            "format": 42,
            "writtenBy": "test",
            "profiles": [["settings": settings]],
        ]
        root["config"] = config
        let out = try #require(
            ConfigMigration.migrated(
                try JSONSerialization.data(withJSONObject: root)
            )
        )
        let migrated = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        #expect(migrated["format"] as? Int == SetupBundle.currentFormat)
        let profiles = try #require(
            migrated["profiles"] as? [[String: Any]]
        )
        return
            ((profiles.first?["settings"] as? [String: Any])?[
                "kiwishelf"
            ] as? [String: Any])?["pocket_visibility"] as? String
    }

    @Test("a format-42 bundle crosses through the migration")
    func bundleThroughMigration() throws {
        let stated: [String: Any] = [
            "format": 18, "pocket": ["capacity": "several"],
        ]
        #expect(try crossedBundle(config: stated) == "always")
        // No group, and no config at all, read as One window.
        #expect(try crossedBundle(config: ["format": 18]) == "hidden")
        #expect(try crossedBundle(config: nil) == "hidden")
    }
}
