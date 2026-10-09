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
                "animations", "app_bar", "border", "drag", "kiwishelf",
                "float_placement", "float_scale_on_display_change",
                "gap",
                "layout", "min_window_size", "mouse",
                "mouse_resize", "new_window_placement_override",
                "shortcut_panel",
                "floating", "resize", "space",
                "space_bar", "space_switch",
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
                "corner_style", "glow", "glow_size",
                "draw_order", "sheen",
            ]
        )
        // 0 is the automatic sentinel (#551): the width-scaled
        // blur formula until the user sets an explicit size.
        #expect(border["glow_size"] as? Double == 0)
        #expect(border["enabled"] as? Bool == true)
        #expect(border["width"] as? Double == 5)
        #expect(border["focused_color"] as? String == "#4A9816")
        #expect(border["unfocused_enabled"] as? Bool == false)
        #expect(border["corner_style"] as? String == "rounded")
        #expect(border["glow"] as? Bool == false)
        #expect(border["draw_order"] as? String == "behind")
        // Bar chrome defaults take the brand kiwi green (#439);
        // pinned here so an accidental struct-default change
        // fails the build, not just the doc-drift breadcrumb.
        // One set for both bars, on the shelf (#1517).
        let shelf = try object(root["kiwishelf"])
        #expect(shelf["active_item_color"] as? String == "#8DB354")
        #expect(shelf["highlight_color"] as? String == "#8DB354")
        // `sticky.set_mark` → `sticky.mark` (#414).
        // Default on: the on-window glyph is the only sticky
        // cue that never depends on another surface.
        // `sticky.set_color` → `sticky.color` (#429); default is
        // the empty "Automatic" sentinel (adaptive label color).
        let sticky = try object(root["sticky"])
        #expect(
            Set(sticky.keys)
                == ["mark", "color", "desktop_reach", "liquid_glass"]
        )
        #expect(sticky["mark"] as? Bool == true)
        // `sticky.set_liquid_glass` (#1621), on by default.
        #expect(sticky["liquid_glass"] as? Bool == true)
        #expect(sticky["color"] as? String == "")
        // `sticky.set_desktop_reach` → `sticky.desktop_reach`
        // (#1145); default ON — the sticky promise spans
        // Desktops wherever the bridge exists.
        #expect(sticky["desktop_reach"] as? Bool == true)
        // `floating.set_color` → `floating.color` (#429): the
        // sticky mark's sibling namespace, also Automatic by
        // default; `floating.set_mark` → `floating.mark` (#1799),
        // default ON.
        let floating = try object(root["floating"])
        #expect(Set(floating.keys) == ["mark", "color"])
        #expect(floating["mark"] as? Bool == true)
        #expect(floating["color"] as? String == "")
        // The `quit` group left for gui.json with #1741
        // (`AppWideSettingsTests`); the key set above holds its
        // absence.
        // `mouse.set_follows_focus` → `mouse.follows_focus`
        // (#186), off by default.
        let mouse = try object(root["mouse"])
        #expect(mouse["follows_focus"] as? Bool == false)
        // `set_swap_skips_cascade` → top-level `swap_skips_cascade`
        // (#172), on by default.
        #expect(root["swap_skips_cascade"] as? Bool == true)
        // `set_float_placement` → top-level `float_placement`
        // (#1674), `center` by default.
        #expect(root["float_placement"] as? String == "center")
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
        // `set_resize_step` → `resize.step` (#58).
        let resize = try object(root["resize"])
        #expect(resize["step"] as? Double == 50)
        // #1307: the panel's leaf is written under its own group.
        // Present and Boolean, never pinned to a value; the three
        // leaves' agreement is `LiquidGlassMasterTests`'.
        let panel = try object(root["shortcut_panel"])
        #expect(
            panel["liquid_glass"] as? Bool
                == TilingSettings().shortcutPanelLiquidGlass
        )
        #expect(resize["feedback"] == nil)
        #expect(root["mouse_resize"] as? String == "layout")
        // Toggles (issue #11) and duration knobs (issue #51).
        // Keys mirror the Lua names per the one-vocabulary rule.
        let animations = try object(root["animations"])
        #expect(animations["on_space_change"] as? Bool == true)
        #expect(animations["on_scrolling"] as? Bool == true)
        #expect(animations["on_window_resize"] as? Bool == true)
        #expect(animations["on_window_swap"] as? Bool == true)
        #expect(animations["on_relayout"] as? Bool == true)
        // `animations.set_duration` → JSON `animations.duration`
        #expect(animations["duration"] as? Int == 150)
        // `animations.set_scroll_duration` → `animations.scroll_duration`
        #expect(animations["scroll_duration"] as? Int == 150)
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
        // `scroll.set_fill_when_alone` →
        // `layout.scroll.fill_when_alone`, on by default (#1389).
        #expect(scroll["fill_when_alone"] as? Bool == true)
        // `grid.set_auto_size` → `layout.grid.auto_size` (#171),
        // off by default.
        let grid = try object(layout["grid"])
        #expect(grid["auto_size"] as? Bool == false)
        // `monocle.set_wrap_focus` → `layout.monocle.wrap_focus`
        // (#168), off by default like scrolling/track (#257).
        let monocle = try object(layout["monocle"])
        #expect(monocle["wrap_focus"] as? Bool == false)
        // `monocle.set_hide_style` → `layout.monocle.hide_style`
        // (#881), `stack` by default — today's behavior.
        #expect(monocle["hide_style"] as? String == "stack")
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
        #expect(stack["fill_when_alone"] as? Bool == true)
        // `track.set_axis` → `layout.track.axis` (#128);
        // wrap toggle per the #168 vocabulary.
        let track = try object(layout["track"])
        #expect(track["axis"] as? String == "vertical")
        // `track.set_auto_tracks` → `layout.track.auto_tracks`
        // (#178), on by default; `limit` is the remembered cap.
        #expect(track["auto_tracks"] as? Bool == true)
        #expect(track["limit"] as? Int == TrackParams().limit)
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
                "drop_zone", "ghost", "liquid_glass",
            ]
        )
        // `drag.set_liquid_glass` (#1620), on by default.
        #expect(drag["liquid_glass"] as? Bool == true)
        let ghost = try object(drag["ghost"])
        #expect(
            Set(ghost.keys) == [
                "border", "border_color",
                "border_alignment", "enabled", "fill", "fill_color",
            ]
        )
        // Kiwi defaults: emerald ghost (origin), amber drop zone
        // (target) — hue carries origin vs. target, and since
        // #511 it has to do so under red-green vision loss too,
        // which is why the ghost is no longer the ring's
        // yellow-green (see DragVisual.ghostDefault).
        #expect(ghost["border_color"] as? String == "#347957")
        #expect(ghost["fill_color"] as? String == "#34795740")
        #expect(ghost["border_alignment"] as? String == "inside")
        let zone = try object(drag["drop_zone"])
        #expect(zone["border_color"] as? String == "#C2790A")
        #expect(zone["fill_color"] as? String == "#C2790A40")
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
    }

    /// `space_bar.set_edge(edge, screen)` →
    /// `space_bar.edge_override`, a sparse map keyed by the
    /// screen's fingerprint beside `edge` — the `gap.override`
    /// shape — and absent while no screen has an edge of its own
    /// (#1948).
    @Test("A bar's per-screen edges sit sparse beside its edge")
    func screenEdgesEncodeSparse() throws {
        let screen = "Studio Display:5120x2880"
        var settings = TilingSettings()
        let plain = try object(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(settings)
            )
        )
        for bar in ["space_bar", "app_bar"] {
            #expect(try object(plain[bar])["edge"] as? String == "top")
            #expect(try object(plain[bar])["edge_override"] == nil)
        }
        settings.spaceBarStyle.setEdge(.left, on: screen)
        settings.appBarStyle.setEdge(.bottom, on: screen)
        let data = try JSONEncoder().encode(settings)
        let root = try object(JSONSerialization.jsonObject(with: data))
        for (bar, edge) in [("space_bar", "left"), ("app_bar", "bottom")] {
            let style = try object(root[bar])
            #expect(style["edge"] as? String == "top")
            #expect(
                style["edge_override"] as? [String: String]
                    == [screen: edge]
            )
        }
        #expect(
            try JSONDecoder().decode(TilingSettings.self, from: data)
                == settings
        )
    }
}
