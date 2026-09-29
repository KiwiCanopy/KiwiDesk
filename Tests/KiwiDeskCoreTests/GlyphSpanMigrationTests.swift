import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.glyph_cap` becomes `glyph_span` (#1528 item 22): a
/// tuned value moves unchanged under the new key in a profile and
/// in a backup's inline profiles, and a file already carrying the
/// new key keeps it. Fixtures are the encoder's own output with
/// the retired key put back, never hand-typed JSON.
@Suite("Glyph span migration (#1528)")
struct GlyphSpanMigrationTests {
    /// Real encoder output for a Space Bar span of `span`, the key
    /// spelled `glyph_cap` as the older build wrote it.
    private func legacySettings(span: Int) throws -> [String: Any] {
        var tiling = TilingSettings()
        tiling.spaceBarStyle.glyphSpan = span
        let data = try JSONEncoder().encode(tiling)
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var bar = try #require(settings["space_bar"] as? [String: Any])
        let value = try #require(bar["glyph_span"] as? Int)
        bar["glyph_span"] = nil
        bar["glyph_cap"] = value
        settings["space_bar"] = bar
        return settings
    }

    private func profile(span: Int, format: Int = 11) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": format,
                "monitor_sets": [String: Any](),
                "settings": legacySettings(span: span),
            ],
            options: [.prettyPrinted]
        )
    }

    private func span(in settings: Any?) throws -> Int {
        let data = try JSONSerialization.data(
            withJSONObject: try #require(settings)
        )
        return try JSONDecoder().decode(TilingSettings.self, from: data)
            .spaceBarStyle.glyphSpan
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    @Test("a profile's tuned span moves to the new key")
    func profileSpanMoves() throws {
        let out = try #require(ConfigMigration.migrated(profile(span: 8)))
        let migrated = try root(out)
        #expect(try span(in: migrated["settings"]) == 8)
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\"glyph_cap\""))
        #expect(migrated["format"] as? Int == Profile.currentFormat)
    }

    @Test("a backup's inline profiles cross too")
    func bundleProfilesCross() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": 16,
                SetupBundle.shapeMarker: "test",
                "profiles": [
                    [
                        "format": 11,
                        "name": "A",
                        "monitor_sets": [String: Any](),
                        "settings": legacySettings(span: 3),
                    ]
                ],
            ]
        )
        let out = try #require(ConfigMigration.migrated(bundle))
        let profiles = try #require(root(out)["profiles"] as? [[String: Any]])
        #expect(try span(in: profiles.first?["settings"]) == 3)
    }

    @Test("a node already carrying the new key keeps it")
    func newKeyWins() throws {
        var settings = try legacySettings(span: 8)
        var bar = try #require(settings["space_bar"] as? [String: Any])
        bar["glyph_span"] = 2
        settings["space_bar"] = bar
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 11,
                "monitor_sets": [String: Any](),
                "settings": settings,
            ]
        )
        let out = try #require(ConfigMigration.migratingRetiredGlyphCap(data))
        #expect(try span(in: root(out)["settings"]) == 2)
    }

    @Test("a file without the retired key is left alone")
    func untouchedWithoutTheKey() throws {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 11,
                "monitor_sets": [String: Any](),
                "settings": try JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(TilingSettings())
                ),
            ]
        )
        #expect(ConfigMigration.migratingRetiredGlyphCap(data) == nil)
    }

    @Test("the retired verb names its replacement")
    func verbIsRetired() {
        #expect(
            APIReference.retirement(of: "space_bar.set_glyph_cap")?
                .contains("space_bar.set_glyph_span") == true
        )
    }
}
