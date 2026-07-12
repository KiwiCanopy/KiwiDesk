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
        settings.spaceIcons[SpaceID(2)] = "globe"
        let data = try JSONEncoder().encode(settings)
        let root = try object(
            JSONSerialization.jsonObject(with: data)
        )
        #expect(
            Set(root.keys) == [
                "animations", "app_bar", "drag", "gap", "layout",
                "min_window_size", "mouse_resize",
                "new_window_placement_override", "resize", "space",
                "swap_skips_cascade",
            ]
        )
        // `set_swap_skips_cascade` → top-level `swap_skips_cascade`
        // (#172), on by default.
        #expect(root["swap_skips_cascade"] as? Bool == true)
        // `set_space_icon` → `space.icon[space_id]` (#68).
        let space = try object(root["space"])
        let icons = try object(space["icon"])
        #expect(icons["2"] as? String == "globe")
        // `set_resize_step` → `resize.step` (#58).
        let resize = try object(root["resize"])
        #expect(resize["step"] as? Double == 50)
        #expect(root["mouse_resize"] as? String == "layout")
        // Toggles (issue #11) and duration knobs (issue #51).
        // Keys mirror the Lua names per the one-vocabulary rule.
        let animations = try object(root["animations"])
        #expect(animations["on_space_change"] as? Bool == false)
        #expect(animations["on_scrolling"] as? Bool == true)
        #expect(animations["on_window_resize"] as? Bool == true)
        #expect(animations["on_window_swap"] as? Bool == true)
        #expect(animations["on_relayout"] as? Bool == true)
        // `animations.set_duration` → JSON `animations.duration`
        #expect(animations["duration"] as? Int == 250)
        // `animations.set_scroll_speed` → `animations.scroll_speed`
        #expect(animations["scroll_speed"] as? Int == 250)
        let layout = try object(root["layout"])
        #expect(
            Set(layout.keys) == [
                "bsp", "grid", "monocle", "scroll", "stack",
                "track",
            ]
        )
        // Lua `bsp.set_ratio_h` / `scroll.set_slot_size`.
        let bsp = try object(layout["bsp"])
        #expect(bsp["ratio_h"] as? Double == 0.5)
        #expect(bsp["ratio_v"] as? Double == 0.5)
        let scroll = try object(layout["scroll"])
        // Default slot size is `auto`, encoded as 0.
        #expect(scroll["slot_size"] as? Double == 0)
        // `scroll.set_wrap_focus` → `layout.scroll.wrap_focus`,
        // off by default (#168).
        #expect(scroll["wrap_focus"] as? Bool == false)
        // `grid.set_auto_size` → `layout.grid.auto_size` (#171),
        // off by default.
        let grid = try object(layout["grid"])
        #expect(grid["auto_size"] as? Bool == false)
        let stack = try object(layout["stack"])
        #expect(stack["master_ratio"] as? Double == 0.6)
        // `track.set_axis` → `layout.track.axis` (#128);
        // wrap toggle per the #168 vocabulary.
        let track = try object(layout["track"])
        #expect(track["axis"] as? String == "vertical")
        #expect(track["count"] as? Int == 0)
        #expect(
            track["overflow_style"] as? String
                == "cascade_overflow"
        )
        #expect(track["new_window"] as? String == "own_track")
        #expect(track["wrap_focus"] as? Bool == false)
        // SpaceID-keyed maps encode as objects, not arrays.
        let gap = try object(root["gap"])
        let gapOverride = try object(gap["override"])
        #expect(Array(gapOverride.keys) == ["2"])
        let placement = try object(
            root["new_window_placement_override"]
        )
        #expect(placement["3"] as? String == "first")
        let drag = try object(root["drag"])
        #expect(
            Set(drag.keys) == [
                "corner_radius", "drop_zone", "ghost",
            ]
        )
        let ghost = try object(drag["ghost"])
        #expect(
            Set(ghost.keys) == [
                "border", "border_color", "border_thickness",
                "border_alignment", "enabled", "fill", "fill_color",
            ]
        )
        // Kiwi defaults: green fill / brown border (ghost),
        // brown fill / green border (drop zone).
        #expect(ghost["border_color"] as? String == "#8B5E3C")
        #expect(ghost["fill_color"] as? String == "#4E9F3D40")
        #expect(ghost["border_thickness"] as? Double == 5)
        #expect(ghost["border_alignment"] as? String == "inside")
        let zone = try object(drag["drop_zone"])
        #expect(zone["border_color"] as? String == "#4E9F3D")
        #expect(zone["fill_color"] as? String == "#8B5E3C40")
        #expect(zone["border_thickness"] as? Double == 5)
        #expect(zone["border_alignment"] as? String == "inside")
    }

    @Test("Partial drag visuals keep the default look")
    func partialDragDecode() throws {
        let json = #"{"drag":{"ghost":{"enabled":false}}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(!decoded.dragGhost.enabled)
        #expect(
            decoded.dragGhost.borderColor
                == DragVisual.ghostDefault.borderColor
        )
        #expect(decoded.dragDropZone == .dropZoneDefault)
        #expect(decoded.dragCornerRadius == 16)
    }

    @Test("Round-trip preserves every setting")
    func roundTrip() throws {
        var settings = TilingSettings()
        settings.bsp.splitRatioH = 0.7
        settings.bsp.splitRatioV = 0.3
        settings.scrolling.slotSize = .points(400)
        settings.stack.masterCount = 2
        settings.grid.rows = 4
        settings.grid.autoSize = true
        settings.track.axis = .horizontal
        settings.track.count = 3
        settings.track.overflowStyle = .cascadeAll
        settings.track.newWindow = .focusedTrack
        settings.track.wrapFocus = true
        settings.minWindowSize = 200
        settings.swapSkipsCascade = false
        settings.resizeStep = 75
        settings.dragGhost.enabled = false
        settings.dragDropZone.fillColor = "#11223344"
        settings.dragCornerRadius = 22
        settings.gapsOverride[SpaceID(2)] = .uniform(4)
        settings.placementOverride[SpaceID("mail")] = .last
        settings.animations.onSpaceChange = true
        settings.animations.onScrolling = false
        settings.animations.onWindowResize = false
        settings.animations.onWindowSwap = false
        settings.animations.onRelayout = false
        settings.animations.durationMS = 400
        settings.animations.scrollSpeedMS = 180
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded == settings)
    }

    @Test("A partial animations object keeps the other default")
    func partialAnimationsDecode() throws {
        let json = #"{"animations":{"on_space_change":true}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.animations.onSpaceChange)
        // on_scrolling absent — keeps its `true` default.
        #expect(decoded.animations.onScrolling)
        // Duration knobs absent — keep their 250 ms defaults.
        #expect(decoded.animations.durationMS == 250)
        #expect(decoded.animations.scrollSpeedMS == 250)
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
