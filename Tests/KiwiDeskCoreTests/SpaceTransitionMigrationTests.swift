import Foundation
import Testing

@testable import KiwiDeskCore

/// `space.cue` (#2228) crosses to `space.transition` (#2524): on
/// becomes the slide, off becomes none, in `gui.json` and a
/// backup's inline `config`, while `desktop.cue` and `mode.cue`
/// stay. Fixtures are the encoder's own output with the #2228
/// group put back, never hand-typed JSON.
@Suite("Space transition migration (#2524)")
struct SpaceTransitionMigrationTests {
    /// A `gui.json` whose `space` group is `{"cue": on}`, stamped
    /// as the build before the crossing wrote it.
    private func legacyGui(cue on: Bool) throws -> [String: Any] {
        var config = GuiConfig()
        config.appWide = AppWideSettings()
        var root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(config)
            ) as? [String: Any]
        )
        #expect(root["space"] != nil)
        root["space"] = ["cue": on]
        root["format"] = 13
        return root
    }

    private func data(_ root: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    @Test(
        "gui.json's cue crosses: on to slide, off to none",
        arguments: [(true, SpaceTransition.slide), (false, .none)]
    )
    func guiCrosses(on: Bool, expected: SpaceTransition) throws {
        let out = try #require(
            ConfigMigration.migrated(data(legacyGui(cue: on)))
        )
        let root = try object(out)
        let space = try #require(root["space"] as? [String: Any])
        #expect(space["cue"] == nil)
        #expect(space["transition"] as? String == expected.rawValue)
        #expect(root["format"] as? Int == GuiConfig.currentFormat)
        #expect((root["desktop"] as? [String: Any])?["cue"] != nil)
        #expect((root["mode"] as? [String: Any])?["cue"] != nil)
        let back = try JSONDecoder().decode(GuiConfig.self, from: out)
        #expect(back.appWide?.spaceTransition == expected)
    }

    /// Compact input: the tree fallback re-encodes pretty-printed,
    /// so a file that stays on one line was edited in place.
    @Test("the crossing is surgical: the file keeps its own shape")
    func surgical() throws {
        let before = try JSONSerialization.data(
            withJSONObject: legacyGui(cue: false)
        )
        let old = try #require(String(data: before, encoding: .utf8))
        #expect(!old.contains("\n"))
        let out = try #require(ConfigMigration.migrated(before))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\n"))
        #expect(text.contains(#""transition":"none""#))
        let edited = try #require(
            ConfigMigration.surgicallyCrossedSpaceCue(old)
        )
        let crossed = try #require(String(data: edited, encoding: .utf8))
        #expect(
            crossed
                == old.replacingOccurrences(
                    of: #""cue":false"#,
                    with: #""transition":"none""#
                )
        )
    }

    @Test("a backup's config crosses")
    func bundleCrosses() throws {
        let bundle = SetupBundle(
            format: 35,
            writtenBy: "test",
            config: GuiConfig(),
            profiles: [],
            palettes: []
        )
        var root = try object(JSONEncoder().encode(bundle))
        root["config"] = try legacyGui(cue: false)
        let out = try #require(ConfigMigration.migrated(data(root)))
        let back = try JSONDecoder().decode(SetupBundle.self, from: out)
        #expect(back.config?.appWide?.spaceTransition == SpaceTransition.none)
    }

    @Test("the retired verbs name their successors")
    func retiredVerbs() {
        for verb in [
            "set_space_cue", "animations.set_space_change",
            "animations.set_on_space_change",
        ] {
            #expect(
                APIReference.retirement(of: verb)?
                    .contains("set_space_transition") == true
            )
        }
        #expect(
            APIReference.retirement(
                of: "animations.set_space_change_duration"
            )?.contains("set_space_slide_duration") == true
        )
    }
}
