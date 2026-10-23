import Foundation
import Testing

@testable import KiwiDeskCore

/// The per-layout `wrap_focus` switches retire (#2493): every file
/// crosses to the one setting's default, All screens, whatever the
/// switches stored (owner ruling 2026-10-23), so the key drops from
/// `layout.scroll`, `layout.monocle` and `layout.track` — in a
/// profile, in `gui.json` and in a backup's inline profiles.
/// Fixtures are the encoder's own output with the retired key put
/// back, never hand-typed JSON.
@Suite("Wrap focus migration (#2493)")
struct WrapFocusMigrationTests {
    /// Real encoder output with `wrap_focus` put back on the three
    /// layouts, one of them on.
    private func legacySettings() throws -> [String: Any] {
        let data = try JSONEncoder().encode(TilingSettings())
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var layout = try #require(settings["layout"] as? [String: Any])
        for (host, value) in [
            ("scroll", false), ("monocle", true), ("track", false),
        ] {
            var params = try #require(layout[host] as? [String: Any])
            params["wrap_focus"] = value
            layout[host] = params
        }
        settings["layout"] = layout
        return settings
    }

    private func profile(pretty: Bool = false) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": 29,
                "monitor_sets": [String: Any](),
                "settings": legacySettings(),
            ],
            options: pretty ? [.prettyPrinted, .sortedKeys] : []
        )
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func mentionsKey(_ data: Data) -> Bool {
        String(decoding: data, as: UTF8.self).contains("\"wrap_focus\"")
    }

    @Test("a profile drops every switch and stores no setting")
    func profileDropsTheKey() throws {
        let out = try #require(ConfigMigration.migrated(profile()))
        #expect(!mentionsKey(out))
        let migrated = try root(out)
        #expect(migrated["format"] as? Int == Profile.currentFormat)
        // No override: the profile follows the base, All screens.
        #expect(migrated["focus_wrap"] == nil)
        let settings = try JSONSerialization.data(
            withJSONObject: try #require(migrated["settings"])
        )
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: settings
        )
        #expect(decoded.scrolling.anchor == TilingSettings().scrolling.anchor)
    }

    @Test("gui.json drops it and reads the default")
    func guiConfigDropsTheKey() throws {
        let gui = try JSONSerialization.data(
            withJSONObject: [
                "format": 15,
                "settings": legacySettings(),
            ]
        )
        let out = try #require(ConfigMigration.migrated(gui))
        #expect(!mentionsKey(out))
        #expect(try root(out)["format"] as? Int == GuiConfig.currentFormat)
        let config = try JSONDecoder().decode(GuiConfig.self, from: out)
        #expect(config.focusWrap == .allScreens)
    }

    @Test("a backup's inline profiles cross too")
    func bundleProfilesCross() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": 38,
                SetupBundle.shapeMarker: "test",
                "profiles": [
                    [
                        "format": 29,
                        "name": "A",
                        "monitor_sets": [String: Any](),
                        "settings": legacySettings(),
                    ]
                ],
            ]
        )
        let out = try #require(ConfigMigration.migrated(bundle))
        #expect(!mentionsKey(out))
        #expect(
            try root(out)["format"] as? Int == SetupBundle.currentFormat
        )
    }

    /// The textual edit itself: only a direct call tells it from the
    /// tree fallback, whose layout the fixture matches.
    @Test("the drop removes only the retired lines")
    func dropIsSurgical() throws {
        let data = try profile(pretty: true)
        let out = try #require(
            ConfigMigration.surgicallyDroppedWrapFocus(
                String(decoding: data, as: UTF8.self)
            )
        )
        let lines = { (data: Data) in
            String(decoding: data, as: UTF8.self)
                .split(separator: "\n", omittingEmptySubsequences: false)
        }
        #expect(lines(data).count - lines(out).count == 3)
        #expect(!mentionsKey(out))
        let edited = try root(out)
        #expect(edited["format"] as? Int == 29)
        #expect(edited["settings"] != nil)
    }

    @Test("a file without the retired key is left alone")
    func untouchedWithoutTheKey() throws {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 29,
                "monitor_sets": [String: Any](),
                "settings": try JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(TilingSettings())
                ),
            ]
        )
        #expect(ConfigMigration.migratingRetiredWrapFocus(data) == nil)
    }
}
