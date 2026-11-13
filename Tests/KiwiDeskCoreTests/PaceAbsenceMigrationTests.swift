import Foundation
import Testing

@testable import KiwiDeskCore

/// An absent slide or fade reads 4.2's 300 ms (#3254): a stored
/// app-wide group's `space.slide_duration` and
/// `kiwivision.fade_duration` are written explicitly where a file left
/// them out, in `gui.json` and a backup's `config`, from the format
/// 4.2.1 stamped; a stated value stays, and a file before #1741 is
/// left alone. Fixtures are the encoder's own output, the leaves then
/// removed.
@Suite("Pace absence migration (#3254)")
struct PaceAbsenceMigrationTests {
    private static let guiFormat42 = 19
    private static let bundleFormat42 = 43

    /// `config` encoded, its slide and fade removed, at `format`.
    private func guiRoot(
        _ config: GuiConfig,
        format: Int
    ) throws -> [String: Any] {
        var root = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(config))
                as? [String: Any]
        )
        for (group, key, _) in ConfigMigration.absentPaceLeaves {
            var leaves = try #require(root[group] as? [String: Any])
            leaves[key] = nil
            root[group] = leaves
        }
        root["format"] = format
        return root
    }

    private var stored: GuiConfig {
        var config = GuiConfig()
        config.appWide = AppWideSettings()
        return config
    }

    private func decoded(_ data: Data) throws -> AppWideSettings? {
        let bytes = ConfigMigration.migrated(data) ?? data
        return try JSONDecoder().decode(GuiConfig.self, from: bytes).appWide
    }

    @Test("a 4.2.1 gui.json's absent slide and fade read 300")
    func guiAbsenceReadsLegacy() throws {
        let data = try JSONSerialization.data(
            withJSONObject: guiRoot(stored, format: Self.guiFormat42)
        )
        let wide = try #require(try decoded(data))
        let legacy = AnimationPacePreset.legacyDefaults
        #expect(wide.spaceSlideDuration == legacy.slide)
        #expect(wide.visionFadeDuration == legacy.fade)
    }

    @Test("a stated slide and fade stay")
    func statedStays() throws {
        var config = stored
        config.appWide?.spaceSlideDuration = 650
        config.appWide?.visionFadeDuration = 150
        var root = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(config))
                as? [String: Any]
        )
        root["format"] = Self.guiFormat42
        let wide = try #require(
            try decoded(JSONSerialization.data(withJSONObject: root))
        )
        #expect(wide.spaceSlideDuration == 650)
        #expect(wide.visionFadeDuration == 150)
    }

    @Test("a 4.2.1 backup's config absence reads 300")
    func bundleAbsenceReadsLegacy() throws {
        let bundle = SetupBundle(
            writtenBy: "4.2",
            config: stored,
            profiles: [],
            palettes: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var root = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(bundle))
                as? [String: Any]
        )
        root["config"] = try guiRoot(stored, format: Self.guiFormat42)
        root["format"] = Self.bundleFormat42
        let data = try JSONSerialization.data(withJSONObject: root)
        let bytes = ConfigMigration.migrated(data) ?? data
        let out = try #require(
            JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        )
        let config = try #require(out["config"] as? [String: Any])
        for (group, key, length) in ConfigMigration.absentPaceLeaves {
            let leaves = try #require(config[group] as? [String: Any])
            #expect(
                leaves[key] as? Int == length,
                "\(group).\(key)"
            )
        }
    }

    /// No app-wide group means the values are owed from the profiles
    /// (#1741), so nothing is stated here.
    @Test("a file before #1741 is left alone")
    func pre1741LeftAlone() throws {
        var root = try guiRoot(stored, format: Self.guiFormat42)
        root["refusal"] = nil
        root["quit"] = nil
        let data = try JSONSerialization.data(withJSONObject: root)
        #expect(ConfigMigration.migratingAbsentSlideAndFade(data) == nil)
    }

    /// At each shape's current format the step stands down, so a
    /// 400 written later is never read as an absence.
    @Test("the step stands down at the current formats")
    func stepIsIdempotent() throws {
        let gui = try JSONSerialization.data(
            withJSONObject: guiRoot(stored, format: GuiConfig.currentFormat)
        )
        #expect(ConfigMigration.migratingAbsentSlideAndFade(gui) == nil)
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                SetupBundle.shapeMarker: "test",
                "format": SetupBundle.currentFormat,
                "config": guiRoot(stored, format: GuiConfig.currentFormat),
            ] as [String: Any]
        )
        #expect(ConfigMigration.migratingAbsentSlideAndFade(bundle) == nil)
    }
}
