import Foundation
import Testing

@testable import KiwiDeskCore

/// Pins the profile JSON vocabulary to the Lua API (AGENTS.md
/// §5): keys are Lua command names with the verb stripped,
/// grouped by namespace. A failure here means the two surfaces
/// drifted apart.
@Suite("Settings JSON coding")
struct SettingsCodingTests {
    private func object(
        _ any: Any?
    ) throws -> [String: Any] {
        try #require(any as? [String: Any])
    }

    @Test("Settings encode with Lua-aligned grouped keys")
    func encodedShape() throws {
        var settings = TilingSettings()
        settings.gapsOverride[SpaceID(2)] = .uniform(4)
        settings.placementOverride[SpaceID(3)] = .first
        let data = try JSONEncoder().encode(settings)
        let root = try object(
            JSONSerialization.jsonObject(with: data)
        )
        #expect(
            Set(root.keys) == [
                "drag", "gap", "layout", "min_window_size",
                "new_window_placement_override",
            ]
        )
        let layout = try object(root["layout"])
        #expect(
            Set(layout.keys) == [
                "bsp", "grid", "scroll", "stack",
            ]
        )
        // Lua `bsp.set_ratio` / `scroll.set_width`.
        let bsp = try object(layout["bsp"])
        #expect(bsp["ratio"] as? Double == 0.5)
        let scroll = try object(layout["scroll"])
        #expect(scroll["width"] as? Double == 800)
        let stack = try object(layout["stack"])
        #expect(stack["master_ratio"] as? Double == 0.6)
        // SpaceID-keyed maps encode as objects, not arrays.
        let gap = try object(root["gap"])
        let gapOverride = try object(gap["override"])
        #expect(Array(gapOverride.keys) == ["2"])
        let placement = try object(
            root["new_window_placement_override"]
        )
        #expect(placement["3"] as? String == "first")
        let drag = try #require(
            root["drag"] as? [String: Bool]
        )
        #expect(drag == ["ghost": true, "drop_zone": true])
    }

    @Test("Round-trip preserves every setting")
    func roundTrip() throws {
        var settings = TilingSettings()
        settings.bsp.splitRatio = 0.7
        settings.scrolling.windowWidth = 400
        settings.stack.masterCount = 2
        settings.grid.rows = 4
        settings.minWindowSize = 200
        settings.dragShowGhost = false
        settings.gapsOverride[SpaceID(2)] = .uniform(4)
        settings.placementOverride[SpaceID("mail")] = .last
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded == settings)
    }

    @Test("Missing keys fall back to defaults")
    func defaults() throws {
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data("{}".utf8)
        )
        #expect(decoded == TilingSettings())
    }
}
