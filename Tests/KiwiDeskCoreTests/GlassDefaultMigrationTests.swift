import Foundation
import Testing

@testable import KiwiDeskCore

/// The Liquid Glass default flip's crossing (#1369): a file below
/// the floor gets every ABSENT glass leaf written as the `false`
/// it meant, the panel group created where it is missing — so an
/// existing setup keeps its look and the one Settings row (#1307)
/// finds its three leaves in agreement. The failure this prevents
/// is silent: bars off beside a panel on, on a plain upgrade.
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

    /// The population the reviewers found: bars written, no
    /// panel group. The panel takes the `false` its absence
    /// meant; the bars keep their own values, whatever they are.
    @Test("an absent panel group is created off, the bars untouched")
    func absentPanelIsFilledOff() throws {
        for bars in [false, true] {
            let data = profile(
                """
                {"app_bar":{"liquid_glass":\(bars),"thickness":32},\
                "space_bar":{"liquid_glass":\(bars)}}
                """
            )
            let out = try #require(ConfigMigration.migrated(data))
            let s = try settings(out)
            #expect(leaf(s, "shortcut_panel") == false)
            #expect(leaf(s, "app_bar") == bars)
            #expect(leaf(s, "space_bar") == bars)
            #expect(
                (s["app_bar"] as? [String: Any])?["thickness"]
                    as? Double == 32
            )
            #expect(try root(out)["format"] as? Int == Profile.currentFormat)
        }
    }

    /// A hand-written file that never set a bar leaf: absent
    /// meant off under the old default, and is written so.
    @Test("absent bar leaves are written off")
    func absentBarLeavesAreFilled() throws {
        let data = profile(
            #"{"app_bar":{"thickness":32},"space_bar":{"edge":"top"}}"#
        )
        let out = try #require(ConfigMigration.migrated(data))
        let s = try settings(out)
        #expect(leaf(s, "app_bar") == false)
        #expect(leaf(s, "space_bar") == false)
        #expect(leaf(s, "shortcut_panel") == false)
    }

    /// A present leaf is a choice: the crossing never rewrites
    /// one, on or off.
    @Test("a present leaf keeps its value")
    func presentLeafIsKept() throws {
        let data = profile(
            """
            {"app_bar":{"liquid_glass":true},\
            "space_bar":{"liquid_glass":true},\
            "shortcut_panel":{"liquid_glass":true}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let s = try settings(out)
        #expect(leaf(s, "app_bar") == true)
        #expect(leaf(s, "space_bar") == true)
        #expect(leaf(s, "shortcut_panel") == true)
    }

    /// A per-layout `app_bar` override holds no `space_bar`
    /// beside it, and its absent leaf means "inherit": writing
    /// `false` there would mint an override nobody set.
    @Test("a per-layout app_bar override is left alone")
    func layoutOverrideIsNotTouched() throws {
        let data = profile(
            """
            {"app_bar":{"liquid_glass":false},\
            "space_bar":{"liquid_glass":false},\
            "monocle":{"app_bar":{"thickness":40}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let s = try settings(out)
        let monocle = try #require(s["monocle"] as? [String: Any])
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

    /// The bundle carries `[Profile]` inline, so the crossing
    /// reaches every profile in it (`ConfigMigrationRoutingTests`'
    /// census obligation).
    @Test("a backup's inline profiles are all filled")
    func bundleProfilesAreFilled() throws {
        func inline(_ name: String, glass: Bool) -> String {
            """
            {"format":3,"name":"\(name)","monitor_sets":[],\
            "settings":{"app_bar":{"liquid_glass":\(glass)},\
            "space_bar":{"liquid_glass":\(glass)}}}
            """
        }
        let one = inline("A", glass: false)
        let two = inline("B", glass: true)
        let data = json(
            """
            {"format":5,"writtenBy":"1.2.2","config":null,\
            "profiles":[\(one),\(two)],"palettes":[]}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let profiles = try #require(
            root(out)["profiles"] as? [[String: Any]]
        )
        #expect(profiles.count == 2)
        for p in profiles {
            let s = try #require(p["settings"] as? [String: Any])
            #expect(leaf(s, "shortcut_panel") == false)
        }
        #expect(try root(out)["format"] as? Int == SetupBundle.currentFormat)
    }

    /// The common shape takes the surgical edit: the user's own
    /// Doubles keep their spelling rather than re-encoding.
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
        #expect(text.contains("0.4,") || text.contains("0.4}"))
        #expect(!text.contains("0.40000000000000002"))
        #expect(leaf(try settings(out), "shortcut_panel") == false)
    }
}
