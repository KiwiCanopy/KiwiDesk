import Foundation
import Testing

@testable import KiwiDeskCore

/// The palettes lift, the format stamp, and the shape-marker
/// routing (#938/#939) — split from `ConfigMigrationTests`
/// for file size (AGENTS.md 2.1).
@Suite("Config migration stamping & palettes")
struct ConfigMigrationStampTests {
    /// UTF-8 bytes of a JSON literal (the shared fixture
    /// helper's shape, duplicated per tests.md's
    /// per-file-helpers convention).
    private func json(_ text: String) -> Data {
        Data(text.utf8)
    }

    /// A legacy bare-array palettes.json is wrapped as
    /// `{"format": N, "palettes": [...]}` (#939).
    @Test("Legacy bare-array palettes file migrates to wrapped format")
    func legacyPalettesArrayMigrates() throws {
        let legacy = json(
            """
            [{"colors":{"app_bar.fill_color":"#123456"},"name":"Mine"}]
            """
        )
        let out = try #require(ConfigMigration.migrated(legacy))
        let root =
            try JSONSerialization.jsonObject(with: out) as? [String: Any]
        #expect(root?["format"] as? Int == PaletteDocument.currentFormat)
        let palettes = root?["palettes"] as? [[String: Any]]
        #expect(palettes?.count == 1)
        #expect(palettes?.first?["name"] as? String == "Mine")
    }

    /// A file that needed migration is stamped with current format
    /// and reports needsMigration == false on next read (#938).
    @Test("Migrated profile is stamped with current format")
    func migratedProfileStampedWithCurrentFormat() throws {
        let unversionedOld = json(
            """
            {"name":"Starter","monitor_sets":[{"monitors":["A:100x100"]}],\
            "space_modes":{"1":"bsp"},\
            "settings":{"app_bar":{"content":"icon_and_name"}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(unversionedOld))
        let root =
            try JSONSerialization.jsonObject(with: out) as? [String: Any]
        #expect(root?["format"] as? Int == Profile.currentFormat)
        #expect(ConfigMigration.needsMigration(out) == false)
        #expect(ConfigMigration.migrated(out) == nil)
    }

    /// A palette document carrying a newer format than supported is refused.
    @Test("A palette document with newer format is refused")
    func newerPaletteFormatIsRefused() {
        let future = PaletteDocument.currentFormat + 1
        let data = json(
            """
            {"format":\(future),"palettes":[{"colors":{},\
            "name":"Future"}]}
            """
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PaletteDocument.self, from: data)
        }
    }

    /// A stale-format file that NO step rewrites is still
    /// stamped (#938): without this the crossing never ends —
    /// `needsMigration` stays true on every read, and a future
    /// floor advance (#902) refuses a valid file this app
    /// wrote. This is the sub-diff the first draft missed: its
    /// stamp ran only when a step changed bytes.
    @Test("A file with nothing to rewrite is still stamped")
    func unversionedFileWithNothingToRewriteIsStamped() throws {
        let plain = json(
            """
            {"gap":{"override":{"inner":{"horizontal":12}}}}
            """
        )
        #expect(ConfigMigration.needsMigration(plain))
        let out = try #require(ConfigMigration.migrated(plain))
        let root =
            try JSONSerialization.jsonObject(with: out)
            as? [String: Any]
        #expect(root?["format"] as? Int == GuiConfig.currentFormat)
        #expect(
            root?["gap"] != nil,
            "the stamp may not drop the payload"
        )
        #expect(ConfigMigration.needsMigration(out) == false)
        #expect(ConfigMigration.migrated(out) == nil)
    }

    /// Each shape marker `targetFormat` routes on appears in the
    /// real encoder output of its owning shape — derived from
    /// the encoders, never restated as literals (the first
    /// draft's test pinned CodingKey rawValues against strings
    /// restated in the test, which guarded nothing;
    /// rule-authoring.md's number-pin rule). The palettes and
    /// bundle arms consult the SAME symbols encoded here, so an
    /// encoder-side rename either moves the marker with it or
    /// reds here.
    @Test("Shape markers appear in their shapes' encoded output")
    func shapeMarkersMatchEncodedShapes() throws {
        func keys(_ data: Data) throws -> Set<String> {
            let root =
                try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
            return Set((root ?? [:]).keys)
        }
        let doc = try JSONEncoder().encode(
            PaletteDocument(palettes: [])
        )
        #expect(
            try keys(doc).contains(
                PaletteDocument.CodingKeys.palettes.rawValue
            )
        )
        let bundle = try JSONEncoder().encode(
            SetupBundle(
                writtenBy: "test",
                config: nil,
                profiles: [],
                palettes: []
            )
        )
        #expect(
            try keys(bundle).contains(SetupBundle.shapeMarker)
        )
        let profile = try JSONEncoder().encode(
            Profile(
                name: "P",
                monitorSets: [],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        #expect(
            try keys(profile).contains(
                Profile.CodingKeys.monitorSets.rawValue
            )
        )
    }
}
