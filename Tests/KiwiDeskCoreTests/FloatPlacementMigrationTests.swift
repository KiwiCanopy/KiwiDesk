import Foundation
import Testing

@testable import KiwiDeskCore

/// Retiring `float_nudge` for `float_placement` (#1674). A
/// stored `false` was a choice and becomes `keep`; a stored
/// `true` was written by every save under the old default and
/// is dropped, so the new `center` default lands on it.
@Suite("Float placement migration (#1674)")
struct FloatPlacementMigrationTests {
    /// Real encoder output with the retired key put back where
    /// the old encoder wrote it, at the top of `TilingSettings`.
    private func legacySettings(nudge: Bool) throws -> [String: Any] {
        let data = try JSONEncoder().encode(TilingSettings())
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        settings["float_placement"] = nil
        settings["float_nudge"] = nudge
        return settings
    }

    /// A profile root stamped at the format before this step.
    private func profile(nudge: Bool) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": 9,
                "monitor_sets": [String: Any](),
                "settings": legacySettings(nudge: nudge),
            ],
            options: [.prettyPrinted]
        )
    }

    private func migratedSettings(_ data: Data) throws -> TilingSettings {
        let out = try #require(ConfigMigration.migrated(data))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let settings = try #require(root["settings"] as? [String: Any])
        #expect(settings["float_nudge"] == nil)
        return try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(withJSONObject: settings)
        )
    }

    @Test("a stored false becomes keep")
    func falseBecomesKeep() throws {
        let settings = try migratedSettings(profile(nudge: false))
        #expect(settings.floatPlacement == .keep)
    }

    @Test("a stored true is dropped onto the new default")
    func trueBecomesCenter() throws {
        let settings = try migratedSettings(profile(nudge: true))
        #expect(settings.floatPlacement == .center)
    }

    @Test("an explicit float_placement beside the retired key wins")
    func explicitNewKeyWins() throws {
        var settings = try legacySettings(nudge: false)
        settings["float_placement"] = "center"
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 9,
                "monitor_sets": [String: Any](),
                "settings": settings,
            ]
        )
        #expect(try migratedSettings(data).floatPlacement == .center)
    }

    @Test("every inline profile of a bundle is reached")
    func bundleProfiles() throws {
        let entry: [String: Any] = [
            "format": 9,
            "monitor_sets": [String: Any](),
            "settings": try legacySettings(nudge: false),
        ]
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 13,
                SetupBundle.shapeMarker: "test",
                "profiles": [entry, entry],
                "palettes": [Any](),
            ]
        )
        let out = try #require(ConfigMigration.migrated(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\"float_nudge\""))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        for profile in profiles {
            let settings = try #require(
                profile["settings"] as? [String: Any]
            )
            #expect(settings["float_placement"] as? String == "keep")
        }
    }

    /// The textual path. The fixture is one the walk's
    /// re-serialization cannot reproduce — four-space indent,
    /// unsorted keys, `0.40` — so an exact match proves the edit
    /// touched only the retired entry.
    @Test("the edit touches only the retired entry")
    func surgicalEdit() throws {
        let text = """
            {
                "settings": { "ratio": 0.40, "float_nudge": false },
                "monitor_sets": {},
                "format": 9
            }
            """
        let out = try #require(
            ConfigMigration.migrated(Data(text.utf8))
        )
        let result = try #require(String(data: out, encoding: .utf8))
        let expected = text.replacingOccurrences(
            of: #""float_nudge": false"#,
            with: #""float_placement": "keep""#
        )
        #expect(stampless(result) == stampless(expected))
    }

    /// The textual drop of a stored `true`, mid-object and last,
    /// on the same unreproducible fixture shape.
    @Test("a stored true is deleted in place, its commas with it")
    func surgicalDrop() throws {
        for (body, kept) in [
            (#""float_nudge": true, "ratio": 0.40"#, #""ratio": 0.40"#),
            (#""ratio": 0.40, "float_nudge": true"#, #""ratio": 0.40"#),
        ] {
            let text = """
                {
                    "settings": { \(body) },
                    "monitor_sets": {},
                    "format": 9
                }
                """
            let out = try #require(
                ConfigMigration.migrated(Data(text.utf8))
            )
            let result = try #require(
                String(data: out, encoding: .utf8)
            )
            let expected = text.replacingOccurrences(
                of: body,
                with: kept
            )
            #expect(stampless(result) == stampless(expected))
        }
    }

    /// The text with its format stamp removed: the stamp is the
    /// envelope's to rewrite, not this step's.
    private func stampless(_ text: String) -> String {
        text.replacingOccurrences(
            of: #""format"\s*:\s*\d+"#,
            with: "",
            options: .regularExpression
        )
    }
}
