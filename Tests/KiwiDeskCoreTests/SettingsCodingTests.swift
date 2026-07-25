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
                "animations", "app_bar", "border", "drag",
                "float_nudge", "float_scale_on_display_change",
                "gap",
                "layout", "min_window_size", "mouse",
                "mouse_resize", "new_window_placement_override", "quit",
                "floating", "resize", "space", "space_bar",
                "sticky", "swap_skips_cascade",
            ]
        )
        // `border.set_*` → `border.*` (#278). Default on,
        // focused-only, 2 pt, rounded, deep-kiwi-green focused
        // color (#439 overlay signal — accent hue darkened).
        let border = try object(root["border"])
        #expect(
            Set(border.keys) == [
                "enabled", "width", "focused_color",
                "unfocused_enabled", "unfocused_color",
                "corner_style", "glow", "draw_order",
            ]
        )
        #expect(border["enabled"] as? Bool == true)
        #expect(border["width"] as? Double == 5)
        #expect(border["focused_color"] as? String == "#588613")
        #expect(border["unfocused_enabled"] as? Bool == false)
        #expect(border["corner_style"] as? String == "rounded")
        #expect(border["glow"] as? Bool == false)
        #expect(border["draw_order"] as? String == "behind")
        // Bar chrome defaults take the brand kiwi green (#439);
        // pinned here so an accidental struct-default change
        // fails the build, not just the doc-drift breadcrumb.
        let appBar = try object(root["app_bar"])
        #expect(appBar["active_item_color"] as? String == "#8DB354")
        #expect(appBar["highlight_color"] as? String == "#8DB354")
        let spaceBar = try object(root["space_bar"])
        #expect(spaceBar["active_item_color"] as? String == "#8DB354")
        #expect(spaceBar["highlight_color"] as? String == "#8DB354")
        // `sticky.set_mark` → `sticky.mark` (#414).
        // Default on: the on-window glyph is the only sticky
        // cue that never depends on another surface.
        // `sticky.set_color` → `sticky.color` (#429); default is
        // the empty "Automatic" sentinel (adaptive label color).
        let sticky = try object(root["sticky"])
        #expect(Set(sticky.keys) == ["mark", "color"])
        #expect(sticky["mark"] as? Bool == true)
        #expect(sticky["color"] as? String == "")
        // `floating.set_color` → `floating.color` (#429): the
        // sticky mark's sibling namespace, also Automatic by
        // default.
        let floating = try object(root["floating"])
        #expect(Set(floating.keys) == ["color"])
        #expect(floating["color"] as? String == "")
        // `quit.set_layout` → `quit.layout` (#197); `grid` is
        // the only strategy today and the default.
        // `quit.set_grid_target_depth` →
        // `quit.grid_target_depth` (#281), standard target 5.
        let quit = try object(root["quit"])
        #expect(quit["layout"] as? String == "grid")
        #expect(quit["grid_target_depth"] as? Double == 5)
        // `mouse.set_follows_focus` → `mouse.follows_focus`
        // (#186), off by default.
        let mouse = try object(root["mouse"])
        #expect(mouse["follows_focus"] as? Bool == false)
        // `set_swap_skips_cascade` → top-level `swap_skips_cascade`
        // (#172), on by default.
        #expect(root["swap_skips_cascade"] as? Bool == true)
        // `set_float_nudge` → top-level `float_nudge`, on by
        // default: a tiled→floating toggle shoves the window
        // toward center so the state change is visible.
        #expect(root["float_nudge"] as? Bool == true)
        // `set_float_scale_on_display_change` → top-level
        // `float_scale_on_display_change` (#502), ON by default:
        // a cross-display float scales to fit unless opted out
        // (supersedes the #444/#493 keep-the-size default).
        #expect(
            root["float_scale_on_display_change"] as? Bool
                == true
        )
        // `set_space_icon` → `space.icon[space_id]` (#68).
        let space = try object(root["space"])
        let icons = try object(space["icon"])
        #expect(icons["2"] as? String == "globe")
        // `set_resize_step` → `resize.step` (#58);
        // `set_resize_feedback` → `resize.feedback` (#184),
        // on by default.
        let resize = try object(root["resize"])
        #expect(resize["step"] as? Double == 50)
        #expect(resize["feedback"] as? Bool == true)
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
        // `scroll.set_anchor` → `layout.scroll.anchor`; `follow`
        // by default (#239 — the minimal-pan behavior).
        #expect(scroll["anchor"] as? String == "follow")
        // `scroll.set_wrap_focus` → `layout.scroll.wrap_focus`,
        // off by default (#168).
        #expect(scroll["wrap_focus"] as? Bool == false)
        // `grid.set_auto_size` → `layout.grid.auto_size` (#171),
        // off by default.
        let grid = try object(layout["grid"])
        #expect(grid["auto_size"] as? Bool == false)
        // `monocle.set_wrap_focus` → `layout.monocle.wrap_focus`
        // (#168), off by default like scrolling/track (#257).
        let monocle = try object(layout["monocle"])
        #expect(monocle["wrap_focus"] as? Bool == false)
        let stack = try object(layout["stack"])
        #expect(stack["master_ratio"] as? Double == 0.6)
        // `stack.set_master_orientation` / `set_stack_position`
        // (#222); the stack zone's lineup derives from the
        // position, so no `stack_orientation` key exists.
        // Masters sit side by side by default.
        #expect(
            stack["master_orientation"] as? String == "horizontal"
        )
        #expect(stack["stack_position"] as? String == "right")
        #expect(stack["stack_orientation"] == nil)
        // `track.set_axis` → `layout.track.axis` (#128);
        // wrap toggle per the #168 vocabulary.
        let track = try object(layout["track"])
        #expect(track["axis"] as? String == "vertical")
        // `track.set_auto_tracks` → `layout.track.auto_tracks`
        // (#178), on by default; `limit` is the remembered cap.
        #expect(track["auto_tracks"] as? Bool == true)
        #expect(track["limit"] as? Int == 2)
        #expect(track["new_window"] as? String == "focused_track")
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
                "border", "border_color", "border_width",
                "border_alignment", "enabled", "fill", "fill_color",
            ]
        )
        // Kiwi defaults: deep-green ghost (origin), amber drop
        // zone (target) — hue carries origin vs. target. The
        // ghost is the brand accent hue darkened for stroke duty.
        #expect(ghost["border_color"] as? String == "#588613")
        #expect(ghost["fill_color"] as? String == "#58861340")
        #expect(ghost["border_width"] as? Double == 5)
        #expect(ghost["border_alignment"] as? String == "inside")
        let zone = try object(drag["drop_zone"])
        #expect(zone["border_color"] as? String == "#C2790A")
        #expect(zone["fill_color"] as? String == "#C2790A40")
        #expect(zone["border_width"] as? Double == 5)
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
        settings.stack.masterOrientation = .vertical
        settings.stack.stackPosition = .top
        settings.grid.rows = 4
        settings.grid.autoSize = true
        settings.monocle.wrapFocus = false
        settings.track.axis = .horizontal
        settings.track.autoTracks = false
        settings.track.limit = 3
        settings.track.newWindow = .focusedTrack
        settings.track.wrapFocus = true
        settings.minWindowSize = 200
        settings.swapSkipsCascade = false
        settings.floatNudge = false
        settings.floatScaleOnDisplayChange = false
        settings.resizeStep = 75
        settings.resizeFeedback = false
        settings.dragGhost.enabled = false
        settings.dragDropZone.fillColor = "#11223344"
        settings.dragCornerRadius = 22
        settings.borderStyle.enabled = false
        settings.borderStyle.width = 6
        settings.borderStyle.focusedColor = "#010203"
        settings.borderStyle.unfocusedEnabled = true
        settings.borderStyle.unfocusedColor = "#04050607"
        settings.borderStyle.cornerStyle = .square
        settings.borderStyle.glow = true
        settings.stickyStyle.mark = false
        settings.stickyStyle.color = "#4E9F3D"
        settings.floatingStyle.color = "#E8A33D"
        settings.spaceBarStyle.stickyBadge = false
        settings.gapsOverride[SpaceID(2)] = .uniform(4)
        settings.placementOverride[SpaceID("mail")] = .last
        settings.animations.onSpaceChange = true
        settings.animations.onScrolling = false
        settings.animations.onWindowResize = false
        settings.animations.onWindowSwap = false
        settings.animations.onRelayout = false
        settings.animations.durationMS = 400
        settings.animations.scrollSpeedMS = 180
        settings.mouse.followsFocus = true
        settings.quitGridTargetDepth = 12
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded == settings)
    }

    @Test("quit.grid_target_depth clamps into range on decode")
    func targetDepthDecodeClamp() throws {
        // A hand-edited profile can't smuggle a value past the
        // range the command and GUI enforce (#281 review).
        for (raw, expected) in [(999, 20), (0, 1), (-7, 1)] {
            let json = Data(
                #"{"quit":{"grid_target_depth":\#(raw)}}"#
                    .utf8
            )
            let decoded = try JSONDecoder().decode(
                TilingSettings.self,
                from: json
            )
            #expect(decoded.quitGridTargetDepth == expected)
        }
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
