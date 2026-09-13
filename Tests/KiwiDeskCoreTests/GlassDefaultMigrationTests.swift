import Foundation
import Testing

@testable import KiwiDeskCore

/// The Liquid Glass default flip's crossing (#1369): a file below
/// the floor gets each absent BAR leaf written as the `false` its
/// absence meant and the panel filled from the bars' agreement —
/// so an existing setup keeps its look and the one Settings row
/// (#1307) finds its three leaves in agreement for every
/// population. The failure this prevents is silent: bars off
/// beside a panel on, or the reverse, on a plain upgrade.
@Suite("Liquid Glass default migration (#1369)")
struct GlassDefaultMigrationTests {
    private func json(_ text: String) -> Data { Data(text.utf8) }

    /// A PROFILE-shaped root at the floor the flip crossed: the
    /// leaves reach disk in a profile and in the bundle carrying
    /// profiles inline, never in gui.json.
    private func profile(_ settings: String, format: Int = 3)
        -> Data
    {
        json(
            """
            {"format":\(format),"monitor_sets":{},\
            "settings":\(settings)}
            """
        )
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
    }

    private func settings(_ data: Data) throws -> [String: Any] {
        try #require(root(data)["settings"] as? [String: Any])
    }

    private func leaf(
        _ settings: [String: Any],
        _ group: String
    ) -> Bool? {
        (settings[group] as? [String: Any])?["liquid_glass"]
            as? Bool
    }

    /// The population the flip missed: bars written, no panel
    /// group. The panel takes the bars' agreement; the bars keep
    /// their own values and their siblings.
    @Test("an absent panel group takes the bars' agreement")
    func absentPanelTakesTheAgreement() throws {
        for bars in [false, true] {
            let data = profile(
                """
                {"app_bar":{"liquid_glass":\(bars),"thickness":32},\
                "space_bar":{"liquid_glass":\(bars)}}
                """
            )
            let out = try #require(ConfigMigration.migrated(data))
            let s = try settings(out)
            #expect(leaf(s, "shortcut_panel") == bars)
            #expect(leaf(s, "app_bar") == bars)
            #expect(leaf(s, "space_bar") == bars)
            #expect(
                (s["app_bar"] as? [String: Any])?["thickness"]
                    as? Double == 32
            )
            #expect(
                try root(out)["format"] as? Int
                    == Profile.currentFormat
            )
        }
    }

    /// Bars that disagree name no opinion the panel can take.
    @Test("disagreeing bars leave the panel off")
    func disagreeingBarsLeaveThePanelOff() throws {
        let data = profile(
            """
            {"app_bar":{"liquid_glass":true},\
            "space_bar":{"liquid_glass":false}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        #expect(leaf(try settings(out), "shortcut_panel") == false)
    }

    /// A hand-written file that set no bar leaf — and one with no
    /// bar group at all: absent meant off, and is written so.
    @Test("absent bar leaves are written off")
    func absentBarLeavesAreFilled() throws {
        for body in [
            #"{"app_bar":{"thickness":32},"space_bar":{"edge":"top"}}"#,
            #"{"app_bar":{"thickness":32}}"#,
            #"{}"#,
        ] {
            let out = try #require(
                ConfigMigration.migrated(profile(body))
            )
            let s = try settings(out)
            #expect(leaf(s, "app_bar") == false)
            #expect(leaf(s, "space_bar") == false)
            #expect(leaf(s, "shortcut_panel") == false)
        }
    }

    /// A present leaf is a choice: the crossing never rewrites
    /// one, on or off.
    @Test("a present leaf keeps its value")
    func presentLeafIsKept() throws {
        let data = profile(
            """
            {"app_bar":{"liquid_glass":true},\
            "space_bar":{"liquid_glass":true},\
            "shortcut_panel":{"liquid_glass":false}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let s = try settings(out)
        #expect(leaf(s, "app_bar") == true)
        #expect(leaf(s, "space_bar") == true)
        #expect(leaf(s, "shortcut_panel") == false)
    }

    /// A per-layout `app_bar` override lives under `layout`, the
    /// shape the encoder writes, and its absent leaf means
    /// inherit: writing `false` there would mint an override.
    @Test("a per-layout app_bar override is left alone")
    func layoutOverrideIsNotTouched() throws {
        let data = profile(
            """
            {"app_bar":{"liquid_glass":false},\
            "space_bar":{"liquid_glass":false},\
            "layout":{"monocle":{"app_bar":{"thickness":40}}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let s = try settings(out)
        let layout = try #require(s["layout"] as? [String: Any])
        let monocle = try #require(
            layout["monocle"] as? [String: Any]
        )
        let override = try #require(
            monocle["app_bar"] as? [String: Any]
        )
        #expect(override["liquid_glass"] == nil)
        #expect(leaf(s, "shortcut_panel") == false)
    }

    /// The floor is what runs the crossing: a file at the new
    /// format is not read again.
    @Test("a file at the current format is not migrated")
    func currentFormatIsNotMigrated() {
        let data = profile(
            #"{"app_bar":{"liquid_glass":false},"space_bar":{}}"#,
            format: Profile.currentFormat
        )
        #expect(ConfigMigration.migrated(data) == nil)
    }

    private func inline(_ name: String, settings: String) -> String {
        """
        {"format":3,"name":"\(name)","monitor_sets":[],\
        "settings":\(settings)}
        """
    }

    /// The bundle carries `[Profile]` inline, so the crossing
    /// reaches every profile in it — each on its own agreement.
    @Test("a backup's inline profiles are each filled")
    func bundleProfilesAreFilled() throws {
        let off = inline(
            "A",
            settings: """
                {"app_bar":{"liquid_glass":false},\
                "space_bar":{"liquid_glass":false}}
                """
        )
        let on = inline(
            "B",
            settings: """
                {"app_bar":{"liquid_glass":true},\
                "space_bar":{"liquid_glass":true}}
                """
        )
        let data = json(
            """
            {"format":5,"writtenBy":"1.2.2","config":null,\
            "profiles":[\(off),\(on)],"palettes":[]}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let profiles = try #require(
            root(out)["profiles"] as? [[String: Any]]
        )
        var panels: [Bool?] = []
        for p in profiles {
            let s = try #require(p["settings"] as? [String: Any])
            panels.append(leaf(s, "shortcut_panel"))
        }
        #expect(panels == [false, true])
        #expect(
            try root(out)["format"] as? Int
                == SetupBundle.currentFormat
        )
    }

    /// The textual edit's stand-down: an empty `settings` beside a
    /// real one makes the insert a stray, the envelope's re-parse
    /// refuses it, and the walk still fills both.
    @Test("a shape the textual edit cannot take falls to the walk")
    func strayEditFallsToTheWalk() throws {
        let data = json(
            """
            {"format":5,"writtenBy":"1.2.2","config":null,\
            "profiles":[\(inline("A", settings: "{}")),\
            \(inline("B", settings: #"{"space_bar":{}}"#))],\
            "palettes":[]}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let profiles = try #require(
            root(out)["profiles"] as? [[String: Any]]
        )
        for p in profiles {
            let s = try #require(p["settings"] as? [String: Any])
            #expect(leaf(s, "app_bar") == false)
            #expect(leaf(s, "space_bar") == false)
            #expect(leaf(s, "shortcut_panel") == false)
        }
    }

    /// The common shape takes the surgical edit: one line stays
    /// one line, and the user's own Doubles keep their spelling.
    @Test("the app-written shape keeps its formatting")
    func surgicalEditKeepsFormatting() throws {
        let data = profile(
            """
            {"app_bar":{"liquid_glass":false,"dim_factor":0.4},\
            "space_bar":{"liquid_glass":false}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\n"))
        #expect(!text.contains("0.40000000000000002"))
        #expect(leaf(try settings(out), "shortcut_panel") == false)
    }
}
