import Foundation

/// The KiwiDesk API surface as data.
///
/// Single source of truth consumed by the Lua registration,
/// the `help`/`list_commands` command, and the did-you-mean
/// suggestions — it can never drift from the real API.
public enum APIReference {
    /// (Lua name on the KiwiDesk table, dispatcher command).
    public static let commands: [(lua: String, command: String)] =
        [
            ("focus", "focus"),
            ("swap", "swap"),
            ("swap_here", "swap_here"),
            ("focus_window", "focus_window"),
            // Bare `space` is canonical (#42): aligned with the
            // event namespace, which uses bare `space` for a
            // Space and `desktop` for macOS desktops.
            ("focus_space", "focus_space"),
            ("focus_space_back", "focus_space_back"),
            ("focus_space_forward", "focus_space_forward"),
            ("focus_space_previous", "focus_space_previous"),
            ("focus_space_next", "focus_space_next"),
            ("focus_display_last", "focus_display_last"),
            ("focus_display", "focus_display"),
            ("move_to_space", "move_to_space"),
            ("move_to_space_and_follow", "move_to_space_and_follow"),
            // The Desktop twins (#884): `desktop` is macOS's,
            // matching the event namespace and the bind verb.
            ("focus_desktop", "focus_desktop"),
            ("move_to_desktop", "move_to_desktop"),
            ("move_to_desktop_and_follow", "move_to_desktop_and_follow"),
            ("move_space_to_display", "move_space_to_display"),
            ("pin_space_to_display", "pin_space_to_display"),
            ("create_space", "create_space"),
            ("delete_space", "delete_space"),
            ("make_floating", "make_floating"),
            ("make_tiled", "make_tiled"),
            ("toggle_floating", "toggle_floating"),
            ("new_window", "new_window"),
            ("close_window", "close_window"),
            ("make_sticky", "make_sticky"),
            ("make_display_sticky", "make_display_sticky"),
            ("make_unsticky", "make_unsticky"),
            ("toggle_sticky", "toggle_sticky"),
            ("toggle_display_sticky", "toggle_display_sticky"),
            ("toggle_maximized", "toggle_maximized"),
            ("pocket", "pocket"),
            ("override_sticky_reach", "override_sticky_reach"),
            ("resize", "resize"),
            ("move_to_track", "move_to_track"),
            ("focus_or_spawn", "focus_or_spawn"),
            ("spawn_new", "spawn_new"),
            ("gather", "gather"),
            ("move_here", "move_here"),
            ("set_mode", "set_mode"),
            ("cycle_mode", "cycle_mode"),
            ("set_mode_cycle", "set_mode_cycle"),
            ("set_gap_global", "set_gap_global"),
            ("set_gap_override", "set_gap_override"),
            ("set_min_window_size", "set_min_window_size"),
            (
                "set_min_window_size_override",
                "set_min_window_size_override"
            ),
            (
                "set_swap_skips_cascade",
                "set_swap_skips_cascade"
            ),
            ("set_float_placement", "set_float_placement"),
            (
                "set_float_scale_on_display_change",
                "set_float_scale_on_display_change"
            ),
            ("set_resize_step", "set_resize_step"),
            ("reset_layout_sizing", "reset_layout_sizing"),
            (
                "set_refusal_sound",
                "set_refusal_sound"
            ),
            ("set_desktop_cue", "set_desktop_cue"),
            ("set_hyper_key", "set_hyper_key"),
            ("set_modifier_sides", "set_modifier_sides"),
            ("set_mode_cue", "set_mode_cue"),
            ("set_space_transition", "set_space_transition"),
            ("set_space_slide_duration", "set_space_slide_duration"),
            ("set_space_history", "set_space_history"),
            ("set_focus_wrap", "set_focus_wrap"),
            ("set_float_automatically", "set_float_automatically"),
            (
                "set_shortcut_panel_liquid_glass",
                "set_shortcut_panel_liquid_glass"
            ),
            ("set_fallback_space", "set_fallback_space"),
            ("set_space_icon", "set_space_icon"),
            (
                "set_new_window_placement_override",
                "set_new_window_placement_override"
            ),
            ("get_state", "get_state"),
            ("get_config_status", "get_config_status"),
            ("explain_window", "explain_window"),
            ("explain_app", "explain_app"),
            ("get_layout_info", "get_layout_info"),
            ("list_monitors", "list_monitors"),
            ("list_windows", "list_windows"),
            ("debug_log", "debug_log"),
            ("reload_config", "reload_config"),
            ("set_mouse_resize", "set_mouse_resize"),
            ("enable_wake_restore", "enable_wake_restore"),
            (
                "set_wake_restore_delay",
                "set_wake_restore_delay"
            ),
            ("help", "help"),
            ("list_commands", "help"),
            ("version", "version"),
            ("save_profile", "save_profile"),
            ("load_profile", "load_profile"),
            ("delete_profile", "delete_profile"),
            (
                "set_default_profile",
                "set_default_profile"
            ),
            ("list_profiles", "list_profiles"),
            ("get_profile_status", "get_profile_status"),
            (
                "bind_profile_to_desktop",
                "bind_profile_to_desktop"
            ),
        ]

    /// The verbs `space_bar` and `app_bar` carry beside a setter
    /// per field (#761): the show/hide action, which writes
    /// nothing stored.
    public static let barActions = ["toggle_reveal"]

    /// The bar a `space_bar.` / `app_bar.` action names, nil for
    /// any other command — the dispatch's one reading of
    /// `barActions`.
    static func barAction(of command: String) -> ShelfBar? {
        for (prefix, bar) in [
            ("space_bar.", ShelfBar.space), ("app_bar.", .app),
        ]
        where command.hasPrefix(prefix)
            && barActions.contains(String(command.dropFirst(prefix.count)))
        {
            return bar
        }
        return nil
    }

    /// Layout sub-APIs exposed as global Lua tables. Keys must
    /// be fresh, valid Lua identifiers: they are interpolated
    /// bare into the typo-guard install chunk, and a name
    /// colliding with a stdlib global (`table`, `os`, …) would
    /// reuse — and metatable — that table.
    public static let namespaces: [String: [String]] = [
        "animations": [
            "set_duration", "set_scroll_duration",
            "set_on_scrolling",
            "set_on_window_resize", "set_on_window_swap",
            "set_on_relayout",
            "set_on_expand", "set_expand_duration", "set_on_peek",
            "set_reveal_duration",
            "set_size_policy", "set_size_rate",
        ],
        "stack": [
            "promote", "demote",
            "set_master_count", "set_master_ratio",
            "set_master_orientation",
            "set_stack_position",
            "set_new_window_placement",
            "set_fill_when_alone",
            "set_master_count_override",
            "set_master_ratio_override",
            "set_master_orientation_override",
            "set_stack_position_override",
        ],
        "bsp": [
            "set_strategy", "set_ratio_h", "set_ratio_v",
            "set_new_window_placement",
            "set_strategy_override",
            "set_ratio_h_override", "set_ratio_v_override",
        ],
        "scroll": [
            "set_slot_size", "set_anchor", "set_orientation",
            "set_new_window_placement",
            "set_fill_when_alone", "set_slot_size_override",
            "set_anchor_override", "set_orientation_override",
            "set_app_bar_visibility", "set_app_bar_active_indicator",
            "set_app_bar_title_cap",
            "set_app_bar_group_adjacent_windows",
        ],
        "space_bar": barActions + [
            "set_reserve", "set_visibility",
            "set_edge",
            "set_glyph_span", "set_glyph_gap",
            "set_group_adjacent_windows", "set_inactive_content",
            "set_item_label",
            "set_active_indicator",
            "set_active_dim_factor", "set_show_front_app",
            "set_front_app_title_cap", "set_hide_empty",
            "set_sticky_badge", "set_spring_delay",
            "set_focused_item_color", "set_focused_highlight_color",
        ],
        "app_bar": barActions + [
            "set_edge", "set_reserve",
            "set_active_indicator",
            "set_title_cap",
            "set_group_adjacent_windows",
        ],
        "kiwishelf": [
            "set_alignment", "set_order", "set_minimum",
            "set_thickness", "set_outer_margin", "set_inner_margin",
            "set_background_style", "set_liquid_glass",
            "set_background_fit", "set_corner_roundness",
            "set_border", "set_border_width",
            "set_highlight_width", "set_item_gap",
            "set_glyph_size", "set_font_size",
            "set_font_family", "set_font_weight", "set_icon_source",
            "set_dim_factor", "set_item_color",
            "set_active_item_color", "set_highlight_color",
            "set_hover_fill_color", "set_hover_item_color",
            "set_fill_color", "set_border_color",
            "set_group_badge_color", "set_group_badge_text_color",
            "set_reveal_timeout", "set_reveal_style", "set_fill_fade",
            "set_tint_hub_and_plates",
        ],
        "grid": [
            "set_type", "set_fill_empty_cells",
            "set_split_direction", "set_dimensions",
            "set_auto_size",
            "set_column_weight", "set_row_weight",
            "set_new_window_placement",
            "set_type_override",
            "set_fill_empty_cells_override",
            "set_split_direction_override",
            "set_dimensions_override",
            "set_auto_size_override",
            "set_column_weight_override",
            "set_row_weight_override",
        ],
        "monocle": [
            "set_orientation", "set_orientation_override",
            "set_hide_style",
            "set_new_window_placement", "set_app_bar_visibility",
            "set_app_bar_active_indicator", "set_app_bar_title_cap",
            "set_app_bar_group_adjacent_windows",
        ],
        "track": [
            "swap",
            "set_axis", "set_limit", "set_auto_tracks",
            "set_new_window", "set_new_window_position",
            "set_axis_override", "set_limit_override",
            "set_auto_tracks_override",
        ],
        "mouse": [
            "set_follows_focus", "set_hover_focus",
            "set_hover_focus_delay",
        ],
        "scroll_gesture": [
            "set_pan", "set_space_step", "set_natural_scrolling",
            "set_long_swipes", "set_step_distance",
        ],
        "quit": [
            "set_layout", "set_grid_target_depth",
        ],
        "drag": [
            "set_ghost_enabled", "set_ghost_border",
            "set_ghost_border_alignment",
            "set_ghost_border_color", "set_ghost_fill",
            "set_ghost_fill_color",
            "set_drop_zone_enabled", "set_drop_zone_border",
            "set_drop_zone_border_alignment",
            "set_drop_zone_border_color",
            "set_drop_zone_fill",
            "set_drop_zone_fill_color",
            "set_liquid_glass",
        ],
        "border": [
            "set_enabled", "set_width", "set_focused_color",
            "set_unfocused_enabled", "set_unfocused_color",
            "set_corner_style", "set_glow", "set_glow_size",
            "set_sheen", "set_draw_order",
            "fit_gaps",
        ],
        "sticky": [
            "set_mark", "set_color", "set_desktop_reach",
            "set_liquid_glass",
        ],
        "floating": [
            "set_mark", "set_color",
        ],
        "pocket": ["set_color"],
        "kiwivision": [
            "toggle", "current", "set_dim", "set_blur", "set_fade_duration",
            "set_fade_curve", "set_appearance",
            "set_clear_wallpaper", "set_clear_app", "set_never_dimmed",
            "define_lens", "delete_lens",
        ],
        "kiwihub": ["show", "set_key"],
        "look": [
            "list", "current", "apply", "save", "delete",
        ],
        "app_rule": [
            "list", "set_space", "remove_space", "set_float",
            "remove_float",
        ],
        "shortcut": ["list", "set", "remove", "list_groups"],
    ]

    /// Lua-only commands on KiwiDesk table bypassing dispatcher (#37).
    public static let luaOnly: [String] = [
        "exec", "bind", "on", "define_layer", "switch_layer",
        "open_settings",
    ]

    /// Command names reachable through dispatcher and CLI/IPC (#37).
    public static var dispatchable: [String] {
        var names = Set(commands.map(\.command))
        for (table, functions) in namespaces {
            for function in functions {
                names.insert("\(table).\(function)")
            }
        }
        names.formUnion(cliOnly)
        return names.sorted()
    }

    /// Full set of command names for census cross-checking
    /// (`APIRecordCensusTests`, `CLIHelpSeamTests`, #1033).
    public static var allCommands: [String] {
        Set(dispatchable).union(luaOnly).sorted()
    }
}
