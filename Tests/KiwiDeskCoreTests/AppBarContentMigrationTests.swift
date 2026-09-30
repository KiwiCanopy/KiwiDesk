import Foundation
import Testing

@testable import KiwiDeskCore

/// `app_bar.content` retires (#1528 item 13): the stored key drops
/// from the global `app_bar` and each layout's `app_bar` override,
/// whatever it held — the v0.9.7 `name` / `icon_and_name`
/// spellings included — in a profile and in a backup's inline
/// profiles, and nowhere else. Fixtures are the encoder's own
/// output with the retired key put back, never hand-typed JSON.
@Suite("App Bar content migration (#1528)")
struct AppBarContentMigrationTests {
    /// Every value an older build could have stored.
    private static let retiredValues = [
        "icon", "title", "icon_and_title", "name", "icon_and_name",
    ]

    /// Real encoder output with `content` put back into the
    /// global App Bar and both layouts' overrides.
    private func legacySettings(content: String) throws -> [String: Any] {
        let data = try JSONEncoder().encode(TilingSettings())
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var bar = try #require(settings["app_bar"] as? [String: Any])
        bar["content"] = content
        settings["app_bar"] = bar
        var layout = try #require(settings["layout"] as? [String: Any])
        for host in ["monocle", "scroll"] {
            var mode = try #require(layout[host] as? [String: Any])
            var own = try #require(mode["app_bar"] as? [String: Any])
            own["content"] = content
            mode["app_bar"] = own
            layout[host] = mode
        }
        settings["layout"] = layout
        return settings
    }

    private func profile(
        content: String,
        format: Int = 13,
        pretty: Bool = false
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": format,
                "monitor_sets": [String: Any](),
                "settings": legacySettings(content: content),
            ],
            options: pretty ? [.prettyPrinted, .sortedKeys] : []
        )
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    /// Every `app_bar` object under `settings`: the global one
    /// and each layout's.
    private func bars(in settings: Any?) throws -> [[String: Any]] {
        let settings = try #require(settings as? [String: Any])
        let layout = try #require(settings["layout"] as? [String: Any])
        return try [try #require(settings["app_bar"] as? [String: Any])]
            + ["monocle", "scroll"].map { host in
                let mode = try #require(layout[host] as? [String: Any])
                return try #require(mode["app_bar"] as? [String: Any])
            }
    }

    @Test(
        "every stored value drops, global and per layout",
        arguments: retiredValues
    )
    func everyValueDrops(value: String) throws {
        let out = try #require(
            ConfigMigration.migrated(profile(content: value))
        )
        let migrated = try root(out)
        let bars = try bars(in: migrated["settings"])
        #expect(bars.count == 3)
        #expect(bars.allSatisfy { $0["content"] == nil })
        #expect(bars.allSatisfy { !$0.isEmpty })
        #expect(migrated["format"] as? Int == Profile.currentFormat)
        let settings = try JSONSerialization.data(
            withJSONObject: try #require(migrated["settings"])
        )
        #expect(
            try JSONDecoder().decode(TilingSettings.self, from: settings)
                == TilingSettings()
        )
    }

    @Test("a backup's inline profiles cross too")
    func bundleProfilesCross() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": 18,
                SetupBundle.shapeMarker: "test",
                "profiles": [
                    [
                        "format": 13,
                        "name": "A",
                        "monitor_sets": [String: Any](),
                        "settings": legacySettings(content: "icon"),
                    ]
                ],
            ]
        )
        let out = try #require(ConfigMigration.migrated(bundle))
        let migrated = try root(out)
        let profiles = try #require(
            migrated["profiles"] as? [[String: Any]]
        )
        let bars = try bars(in: profiles.first?["settings"])
        #expect(bars.allSatisfy { $0["content"] == nil })
        #expect(migrated["format"] as? Int == SetupBundle.currentFormat)
    }

    /// The textual edit itself, not the envelope: the fixture's
    /// layout is what the tree fallback writes, so only a direct
    /// call can tell the edit from the fallback.
    @Test("the drop removes only the retired lines")
    func dropIsSurgical() throws {
        let data = try profile(content: "icon", pretty: true)
        let out = try #require(
            ConfigMigration.surgicallyDroppedAppBarContent(
                String(decoding: data, as: UTF8.self)
            )
        )
        let lines = { (data: Data) in
            String(decoding: data, as: UTF8.self)
                .split(separator: "\n", omittingEmptySubsequences: false)
        }
        let kept = lines(data).filter { !$0.contains("\"content\"") }
        #expect(lines(data).count - kept.count == 3)
        #expect(lines(out) == kept)
    }

    /// Scoped to an `app_bar` parent: `content` is a common word,
    /// and a later config gaining one elsewhere keeps it.
    @Test("a content key under another parent survives")
    func otherParentsKeepTheirs() throws {
        var settings = try legacySettings(content: "icon")
        settings["elsewhere"] = ["content": "kept"]
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 13,
                "monitor_sets": [String: Any](),
                "settings": settings,
            ]
        )
        let out = try #require(
            ConfigMigration.migratingRetiredAppBarContent(data)
        )
        let migrated = try #require(root(out)["settings"] as? [String: Any])
        let other = try #require(migrated["elsewhere"] as? [String: Any])
        #expect(other["content"] as? String == "kept")
        #expect(try bars(in: migrated).allSatisfy { $0["content"] == nil })
    }

    @Test("a file without the retired key is left alone")
    func untouchedWithoutTheKey() throws {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": 13,
                "monitor_sets": [String: Any](),
                "settings": try JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(TilingSettings())
                ),
            ]
        )
        #expect(ConfigMigration.migratingRetiredAppBarContent(data) == nil)
    }

    @MainActor
    @Test("the retired verbs fail and say why, naming no replacement")
    func verbsAreRetired() {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwidesk-\(UUID())")
        )
        for verb in [
            "app_bar.set_content", "monocle.set_app_bar_content",
            "scroll.set_app_bar_content",
        ] {
            #expect(APIReference.retired[verb] == .some(nil), "\(verb)")
            let response = core.execute(verb, args: [.string("icon")])
            #expect(!response.isSuccess, "\(verb)")
            #expect(
                response.error?.contains("icon and title") == true,
                "\(verb)"
            )
        }
    }
}
