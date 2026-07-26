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
            // Bare `space` is canonical (#42): aligned with the
            // event namespace, which uses bare `space` for a
            // virtual space and `native_space` for macOS desktops.
            ("focus_space", "focus_space"),
            ("move_to_space", "move_to_space"),
            ("move_to_space_and_follow", "move_to_space_and_follow"),
            ("move_space_to_display", "move_space_to_display"),
            ("pin_space_to_display", "pin_space_to_display"),
            ("create_space", "create_space"),
            ("delete_space", "delete_space"),
            ("make_floating", "make_floating"),
            ("make_tiled", "make_tiled"),
            ("make_auto", "make_auto"),
            ("toggle_floating", "toggle_floating"),
            ("make_sticky", "make_sticky"),
            ("make_display_sticky", "make_display_sticky"),
            ("make_unsticky", "make_unsticky"),
            ("toggle_sticky", "toggle_sticky"),
            ("toggle_display_sticky", "toggle_display_sticky"),
            ("resize", "resize"),
            ("move_to_track", "move_to_track"),
            ("pull_or_spawn", "pull_or_spawn"),
            ("spawn_new", "spawn_new"),
            ("set_mode", "set_mode"),
            ("set_gap_global", "set_gap_global"),
            ("set_gap_override", "set_gap_override"),
            ("set_min_window_size", "set_min_window_size"),
            (
                "set_swap_skips_cascade",
                "set_swap_skips_cascade"
            ),
            ("set_float_nudge", "set_float_nudge"),
            (
                "set_float_scale_on_display_change",
                "set_float_scale_on_display_change"
            ),
            ("set_resize_step", "set_resize_step"),
            (
                "set_resize_feedback",
                "set_resize_feedback"
            ),
            ("set_fallback_space", "set_fallback_space"),
            ("set_space_icon", "set_space_icon"),
            (
                "set_new_window_placement_override",
                "set_new_window_placement_override"
            ),
            ("get_state", "get_state"),
            ("get_layout_info", "get_layout_info"),
            ("list_monitors", "list_monitors"),
            ("debug_log", "debug_log"),
            ("reload_config", "reload_config"),
            (
                "set_animation_duration",
                "set_animation_duration"
            ),
            ("set_space_animation", "set_space_animation"),
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
                "bind_profile_to_native_space",
                "bind_profile_to_native_space"
            ),
        ]

    /// Layout sub-APIs exposed as global Lua tables. Keys must
    /// be fresh, valid Lua identifiers: they are interpolated
    /// bare into the typo-guard install chunk, and a name
    /// colliding with a stdlib global (`table`, `os`, …) would
    /// reuse — and metatable — that table.
    public static let namespaces: [String: [String]] = [
        "animations": [
            "set_duration", "set_scroll_speed",
            "set_on_space_change", "set_on_scrolling",
            "set_on_window_resize", "set_on_window_swap",
            "set_on_relayout",
        ],
        "stack": [
            "promote", "demote",
            "set_master_count", "set_master_ratio",
            "set_overflow_style",
            "set_master_orientation",
            "set_stack_position",
            "set_new_window_placement",
            "set_master_count_override",
            "set_master_ratio_override",
            "set_overflow_style_override",
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
            "set_slot_size", "set_anchor", "set_speed",
            "set_orientation", "set_new_window_placement",
            "set_wrap_focus",
            "set_slot_size_override", "set_anchor_override",
            "set_orientation_override",
            "set_app_bar_enabled", "set_app_bar_edge", "set_app_bar_alignment",
            "set_app_bar_thickness",
            "set_app_bar_background_style",
            "set_app_bar_liquid_glass",
            "set_app_bar_background_fit",
            "set_app_bar_active_indicator",
            "set_app_bar_item_size",
            "set_app_bar_item_gap", "set_app_bar_content",
            "set_app_bar_icon_source",
            "set_app_bar_font_size",
            "set_app_bar_corner_roundness",
            "set_app_bar_dim_factor",
            "set_app_bar_group_adjacent_windows",
            "set_app_bar_item_color", "set_app_bar_fill_color",
            "set_app_bar_active_item_color",
            "set_app_bar_highlight_color",
            "set_app_bar_hover_fill_color",
            "set_app_bar_hover_item_color",
            "set_app_bar_group_badge_color",
            "set_app_bar_group_badge_text_color",
        ],
        "space_bar": [
            "set_enabled", "set_edge", "set_alignment", "set_thickness",
            "set_item_size", "set_item_gap", "set_font_size",
            "set_glyph_cap",
            "set_icon_source", "set_background_style",
            "set_liquid_glass",
            "set_background_fit",
            "set_active_indicator", "set_corner_roundness",
            "set_dim_factor", "set_active_dim_factor",
            "set_show_front_app", "set_hide_empty",
            "set_sticky_badge",
            "set_spring_delay",
            "set_item_color", "set_active_item_color",
            "set_focused_item_color",
            "set_hover_fill_color", "set_hover_item_color",
            "set_fill_color",
            "set_highlight_color",
            "set_group_badge_color",
            "set_group_badge_text_color",
        ],
        "app_bar": [
            "set_edge", "set_alignment", "set_thickness",
            "set_background_style",
            "set_liquid_glass",
            "set_background_fit",
            "set_active_indicator", "set_item_size",
            "set_item_gap", "set_content", "set_icon_source",
            "set_font_size",
            "set_corner_roundness",
            "set_dim_factor",
            "set_group_adjacent_windows",
            "set_item_color", "set_fill_color",
            "set_active_item_color",
            "set_highlight_color", "set_hover_fill_color",
            "set_hover_item_color",
            "set_group_badge_color",
            "set_group_badge_text_color",
        ],
        "grid": [
            "set_type", "set_fill_empty_space",
            "set_split_direction", "set_dimensions",
            "set_auto_size",
            "set_new_window_placement",
            "set_type_override",
            "set_fill_empty_space_override",
            "set_split_direction_override",
            "set_dimensions_override",
            "set_auto_size_override",
        ],
        "monocle": [
            "set_orientation", "set_orientation_override",
            "set_wrap_focus", "set_new_window_placement",
            "set_app_bar_enabled", "set_app_bar_edge", "set_app_bar_alignment",
            "set_app_bar_thickness",
            "set_app_bar_background_style",
            "set_app_bar_liquid_glass",
            "set_app_bar_background_fit",
            "set_app_bar_active_indicator",
            "set_app_bar_item_size",
            "set_app_bar_item_gap",
            "set_app_bar_content",
            "set_app_bar_icon_source",
            "set_app_bar_font_size",
            "set_app_bar_corner_roundness",
            "set_app_bar_dim_factor",
            "set_app_bar_item_color", "set_app_bar_fill_color",
            "set_app_bar_active_item_color",
            "set_app_bar_highlight_color",
            "set_app_bar_hover_fill_color",
            "set_app_bar_hover_item_color",
            "set_app_bar_group_adjacent_windows",
            "set_app_bar_group_badge_color",
            "set_app_bar_group_badge_text_color",
        ],
        "track": [
            "swap",
            "set_axis", "set_limit", "set_auto_tracks",
            "set_new_window", "set_new_window_position",
            "set_overflow_style", "set_wrap_focus",
            "set_axis_override", "set_limit_override",
            "set_auto_tracks_override",
            "set_overflow_style_override",
        ],
        "mouse": [
            "set_follows_focus"
        ],
        "quit": [
            "set_layout", "set_grid_target_depth",
        ],
        "drag": [
            "set_ghost_enabled", "set_ghost_border",
            "set_ghost_border_width",
            "set_ghost_border_alignment",
            "set_ghost_border_color", "set_ghost_fill",
            "set_ghost_fill_color",
            "set_drop_zone_enabled", "set_drop_zone_border",
            "set_drop_zone_border_width",
            "set_drop_zone_border_alignment",
            "set_drop_zone_border_color",
            "set_drop_zone_fill",
            "set_drop_zone_fill_color",
            "set_corner_radius",
        ],
        "border": [
            "set_enabled", "set_width", "set_focused_color",
            "set_unfocused_enabled", "set_unfocused_color",
            "set_corner_style", "set_glow", "set_glow_size",
            "set_draw_order",
            "fit_gaps",
        ],
        "sticky": [
            "set_mark", "set_color",
        ],
        "floating": [
            "set_color"
        ],
    ]

    /// Lua-only entry points on the `KiwiDesk` table that
    /// are not routed through the dispatcher and therefore
    /// absent from the CLI/IPC socket. Listed here so
    /// `help()` / `list_commands` cover the full Lua API
    /// surface. Deliberately excluded from did-you-mean
    /// (`suggestion`), which must only hint at commands the
    /// caller's channel can invoke (issue #37).
    public static let luaOnly: [String] = [
        "exec", "bind", "on", "define_mode", "switch_mode",
        "show_shortcuts",
    ]

    /// Command names reachable through the dispatcher (and thus
    /// the CLI/IPC socket): dispatcher verbs, namespace
    /// sub-commands, and `subscribe`. This is the did-you-mean
    /// set — a typo hint must never point at a command the
    /// caller's channel cannot invoke, so the Lua-only entry
    /// points are deliberately excluded here (issue #37).
    public static var dispatchable: [String] {
        var names = Set(commands.map(\.command))
        for (table, functions) in namespaces {
            for function in functions {
                names.insert("\(table).\(function)")
            }
        }
        names.insert("subscribe")
        return names.sorted()
    }

    /// Every command name shown by `help()` / `list_commands`,
    /// sorted — the full Lua-visible surface: everything
    /// dispatchable plus the Lua-only entry points that bypass
    /// the dispatcher (`exec`, `bind`, …).
    public static var allCommands: [String] {
        Set(dispatchable).union(luaOnly).sorted()
    }
}
