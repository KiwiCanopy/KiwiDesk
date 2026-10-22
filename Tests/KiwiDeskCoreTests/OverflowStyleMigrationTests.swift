import Foundation
import Testing

@testable import KiwiDeskCore

/// `overflow_style` retires (#2235): a Stack zone or Track track
/// scrolls its overflow, so the stored key drops from
/// `layout.stack`, `layout.track` and each Space's override under
/// them — in a profile, in `gui.json` and in a backup's inline
/// profiles. Fixtures are the encoder's own output with the
/// retired key put back, never hand-typed JSON.
@Suite("Overflow style migration (#2235)")
struct OverflowStyleMigrationTests {
    /// Real encoder output with `overflow_style` put back on both
    /// layouts and on one Space's override of each.
    private func legacySettings() throws -> [String: Any] {
        let data = try JSONEncoder().encode(TilingSettings())
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var layout = try #require(settings["layout"] as? [String: Any])
        for (host, value, kept) in [
            ("stack", "cascade_overflow", "master_count"),
            ("track", "cascade_all", "limit"),
        ] {
            var params = try #require(layout[host] as? [String: Any])
            params["overflow_style"] = value
            params["override"] = [
                "3": ["overflow_style": value, kept: 2]
            ]
            layout[host] = params
        }
        settings["layout"] = layout
        return settings
    }

    private func profile(pretty: Bool = false) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": 28,
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

    /// Whether `overflow_style` appears anywhere in the bytes.
    private func mentionsKey(_ data: Data) -> Bool {
        String(decoding: data, as: UTF8.self)
            .contains("\"overflow_style\"")
    }

    @Test("a profile drops every stored overflow style")
    func profileDropsTheKey() throws {
        let out = try #require(ConfigMigration.migrated(profile()))
        #expect(!mentionsKey(out))
        let migrated = try root(out)
        #expect(migrated["format"] as? Int == Profile.currentFormat)
        let settings = try JSONSerialization.data(
            withJSONObject: try #require(migrated["settings"])
        )
        // Everything beside the retired key survives the crossing.
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: settings
        )
        #expect(decoded.stack.override["3"]?.masterCount == 2)
        #expect(decoded.track.override["3"]?.limit == 2)
    }

    @Test("gui.json drops it too")
    func guiConfigDropsTheKey() throws {
        let gui = try JSONSerialization.data(
            withJSONObject: [
                "format": 14,
                "settings": legacySettings(),
            ]
        )
        let out = try #require(ConfigMigration.migrated(gui))
        #expect(!mentionsKey(out))
        #expect(try root(out)["format"] as? Int == GuiConfig.currentFormat)
    }

    @Test("a backup's inline profiles cross too")
    func bundleProfilesCross() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": 37,
                SetupBundle.shapeMarker: "test",
                "profiles": [
                    [
                        "format": 28,
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

    /// The textual edit itself: only a direct call tells it from
    /// the tree fallback, whose layout the fixture matches.
    @Test("the drop removes only the retired lines")
    func dropIsSurgical() throws {
        let data = try profile(pretty: true)
        let out = try #require(
            ConfigMigration.surgicallyDroppedOverflowStyle(
                String(decoding: data, as: UTF8.self)
            )
        )
        let lines = { (data: Data) in
            String(decoding: data, as: UTF8.self)
                .split(separator: "\n", omittingEmptySubsequences: false)
        }
        // Four lines go, and only they: what is left still parses,
        // the comma a last entry leaves dangling dropped with it.
        #expect(lines(data).count - lines(out).count == 4)
        #expect(!mentionsKey(out))
        let edited = try root(out)
        #expect(edited["format"] as? Int == 28)
        #expect(edited["settings"] != nil)
    }

    @Test("a file without the retired key is left alone")
    func untouchedWithoutTheKey() throws {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 28,
                "monitor_sets": [String: Any](),
                "settings": try JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(TilingSettings())
                ),
            ]
        )
        #expect(ConfigMigration.migratingRetiredOverflowStyle(data) == nil)
    }

    @MainActor
    @Test("the retired verbs fail and say why, naming no replacement")
    func verbsAreRetired() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwidesk-\(UUID())")
        )
        for verb in [
            "stack.set_overflow_style",
            "stack.set_overflow_style_override",
            "track.set_overflow_style",
            "track.set_overflow_style_override",
        ] {
            #expect(APIReference.retired[verb] == .some(nil), "\(verb)")
            let response = core.execute(
                verb,
                args: [.string("cascade_all")]
            )
            #expect(!response.isSuccess, "\(verb)")
            #expect(response.error?.contains("scrolls") == true, "\(verb)")
        }
    }
}
