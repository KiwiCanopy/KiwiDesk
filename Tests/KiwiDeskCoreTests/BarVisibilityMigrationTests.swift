import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar's on/off switch becomes its visibility (#761): stored off
/// is `hidden`, stored on keeps its value — `always` where it had
/// none — in a profile and a backup's inline profiles, and the
/// global `app_bar.visibility` an unreleased build wrote moves onto
/// each layout's App Bar that was on. Fixtures are the encoder's own
/// output with the retired keys put back, never hand-typed JSON.
@Suite("Bar visibility migration (#761)")
struct BarVisibilityMigrationTests {
    /// Encoder output, then rewritten to the older shape: each bar's
    /// `enabled`, no per-layout `visibility`, and optionally a global
    /// App Bar `visibility`.
    private func legacySettings(
        space: Bool,
        monocle: Bool,
        scrolling: Bool,
        appGlobal: String? = nil
    ) throws -> [String: Any] {
        let data = try JSONEncoder().encode(TilingSettings())
        var settings = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var bar = try #require(settings["space_bar"] as? [String: Any])
        bar["visibility"] = nil
        bar["enabled"] = space
        settings["space_bar"] = bar
        if let appGlobal {
            var app = try #require(settings["app_bar"] as? [String: Any])
            app["visibility"] = appGlobal
            settings["app_bar"] = app
        }
        var layouts = try #require(settings["layout"] as? [String: Any])
        for (name, on) in ["monocle": monocle, "scroll": scrolling] {
            var layout = try #require(layouts[name] as? [String: Any])
            var appBar = try #require(layout["app_bar"] as? [String: Any])
            appBar["visibility"] = nil
            appBar["enabled"] = on
            layout["app_bar"] = appBar
            layouts[name] = layout
        }
        settings["layout"] = layouts
        return settings
    }

    private func profile(_ settings: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": 23,
                "monitor_sets": [String: Any](),
                "settings": settings,
            ],
            options: [.prettyPrinted]
        )
    }

    private func decoded(_ data: Data) throws -> TilingSettings {
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let settings = try JSONSerialization.data(
            withJSONObject: try #require(root["settings"])
        )
        return try JSONDecoder().decode(TilingSettings.self, from: settings)
    }

    @Test("a bar stored off becomes hidden, one stored on always")
    func offIsHiddenOnIsAlways() throws {
        let data = try profile(
            legacySettings(space: false, monocle: true, scrolling: false)
        )
        let out = try #require(ConfigMigration.migrated(data))
        let settings = try decoded(out)
        #expect(settings.spaceBarStyle.visibility == .hidden)
        #expect(settings.monocle.appBar.visibility == .always)
        #expect(settings.scrolling.appBar.visibility == .hidden)
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\"enabled\" : false"))
    }

    @Test("an update shows every user what they saw")
    func onBarsStayShown() throws {
        let data = try profile(
            legacySettings(space: true, monocle: true, scrolling: true)
        )
        let settings = try decoded(
            try #require(ConfigMigration.migrated(data))
        )
        #expect(settings.spaceBarStyle.visibility == .always)
        #expect(settings.monocle.appBar.visibility == .always)
        #expect(settings.scrolling.appBar.visibility == .always)
    }

    @Test("a global App Bar value moves onto each layout that was on")
    func globalMovesToLayouts() throws {
        let data = try profile(
            legacySettings(
                space: true,
                monocle: true,
                scrolling: false,
                appGlobal: "auto"
            )
        )
        let out = try #require(ConfigMigration.migrated(data))
        let settings = try decoded(out)
        #expect(settings.monocle.appBar.visibility == .auto)
        #expect(settings.scrolling.appBar.visibility == .hidden)
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let tiling = try #require(root["settings"] as? [String: Any])
        let app = try #require(tiling["app_bar"] as? [String: Any])
        #expect(app["visibility"] == nil)
    }

    /// A sparse file whose layout carries no App Bar keeps the
    /// global value there rather than losing it with the key.
    @Test("a global value reaches a layout the file left out")
    func globalSeedsAMissingLayout() throws {
        var settings = try legacySettings(
            space: true,
            monocle: true,
            scrolling: true,
            appGlobal: "auto"
        )
        var layouts = try #require(settings["layout"] as? [String: Any])
        layouts["scroll"] = nil
        settings["layout"] = layouts
        let out = try #require(ConfigMigration.migrated(profile(settings)))
        let migrated = try decoded(out)
        #expect(migrated.scrolling.appBar.visibility == .auto)
        #expect(migrated.monocle.appBar.visibility == .auto)
    }

    @Test("a backup's inline profiles cross too")
    func bundleProfilesCross() throws {
        let inner = try #require(
            JSONSerialization.jsonObject(
                with: try profile(
                    legacySettings(
                        space: false,
                        monocle: true,
                        scrolling: true
                    )
                )
            ) as? [String: Any]
        )
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": 29,
                SetupBundle.shapeMarker: "test",
                "profiles": [inner],
            ]
        )
        let out = try #require(ConfigMigration.migrated(bundle))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        let settings = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(
                withJSONObject: try #require(profiles.first?["settings"])
            )
        )
        #expect(settings.spaceBarStyle.visibility == .hidden)
    }

    @Test("a current file is left alone")
    func currentFileIsUntouched() throws {
        var tiling = TilingSettings()
        tiling.spaceBarStyle.visibility = .auto
        tiling.scrolling.appBar.visibility = .hidden
        let settings = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(tiling)
            ) as? [String: Any]
        )
        let (_, changed) = ConfigMigration.withBarVisibility(
            ["settings": settings]
        )
        #expect(!changed)
    }
}
