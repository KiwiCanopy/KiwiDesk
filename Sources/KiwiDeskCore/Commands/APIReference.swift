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
            ("focus_space", "focus_virtual_space"),
            ("focus_virtual_space", "focus_virtual_space"),
            ("move_to_space", "move_to_virtual_space"),
            ("move_to_virtual_space", "move_to_virtual_space"),
            (
                "move_to_space_and_follow",
                "move_to_virtual_space_and_follow"
            ),
            (
                "move_to_virtual_space_and_follow",
                "move_to_virtual_space_and_follow"
            ),
            ("make_floating", "make_floating"),
            ("make_tiled", "make_tiled"),
            ("resize", "resize"),
            ("pull_or_spawn", "pull_or_spawn"),
            ("spawn_new", "spawn_new"),
            ("set_mode", "set_mode"),
            ("set_gap_global", "set_gap_global"),
            ("set_gap_override", "set_gap_override"),
            ("set_min_window_size", "set_min_window_size"),
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

    /// Layout sub-APIs exposed as global Lua tables.
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
            "set_new_window_placement",
            "set_master_count_override",
            "set_master_ratio_override",
            "set_overflow_style_override",
        ],
        "bsp": [
            "set_strategy", "set_ratio",
            "set_new_window_placement",
            "set_strategy_override", "set_ratio_override",
        ],
        "scroll": [
            "set_slot_size", "set_anchor", "set_speed",
            "set_orientation", "set_new_window_placement",
            "set_slot_size_override", "set_anchor_override",
            "set_orientation_override",
            "set_app_bar_enabled", "set_app_bar_position",
            "set_app_bar_thickness", "set_app_bar_style",
            "set_app_bar_active_style", "set_app_bar_item_size",
            "set_app_bar_item_gap", "set_app_bar_content",
            "set_app_bar_font_size", "set_app_bar_corner_radius",
            "set_app_bar_group_adjacent_windows",
            "set_app_bar_text_color", "set_app_bar_box_color",
            "set_app_bar_active_text_color",
            "set_app_bar_active_box_color",
            "set_app_bar_highlight_color", "set_app_bar_hover_color",
            "set_app_bar_hover_text_color",
            "set_app_bar_background_color",
            "set_app_bar_group_badge_color",
            "set_app_bar_group_badge_text_color",
        ],
        "app_bar": [
            "set_position", "set_thickness", "set_style",
            "set_active_style", "set_item_size",
            "set_item_gap", "set_content", "set_font_size",
            "set_corner_radius",
            "set_group_adjacent_windows",
            "set_text_color", "set_box_color",
            "set_active_text_color", "set_active_box_color",
            "set_highlight_color", "set_hover_color",
            "set_hover_text_color", "set_background_color",
            "set_group_badge_color",
            "set_group_badge_text_color",
        ],
        "grid": [
            "set_type", "set_fill_empty_space",
            "set_split_direction", "set_dimensions",
            "set_new_window_placement",
            "set_type_override",
            "set_fill_empty_space_override",
            "set_split_direction_override",
            "set_dimensions_override",
        ],
        "monocle": [
            "set_orientation", "set_orientation_override",
            "set_app_bar_enabled", "set_app_bar_position",
            "set_app_bar_thickness", "set_app_bar_style",
            "set_app_bar_active_style", "set_app_bar_item_size",
            "set_app_bar_item_gap",
            "set_app_bar_content", "set_app_bar_font_size",
            "set_app_bar_corner_radius",
            "set_app_bar_text_color", "set_app_bar_box_color",
            "set_app_bar_active_text_color",
            "set_app_bar_active_box_color",
            "set_app_bar_highlight_color",
            "set_app_bar_hover_color",
            "set_app_bar_hover_text_color",
            "set_app_bar_background_color",
            "set_app_bar_group_adjacent_windows",
            "set_app_bar_group_badge_color",
            "set_app_bar_group_badge_text_color",
        ],
        "drag": [
            "set_ghost_enabled", "set_ghost_border",
            "set_ghost_border_thickness",
            "set_ghost_border_alignment",
            "set_ghost_border_color", "set_ghost_fill",
            "set_ghost_fill_color",
            "set_drop_zone_enabled", "set_drop_zone_border",
            "set_drop_zone_border_thickness",
            "set_drop_zone_border_alignment",
            "set_drop_zone_border_color",
            "set_drop_zone_fill",
            "set_drop_zone_fill_color",
            "set_corner_radius",
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

    /// A close known command for a typo, if any. Suggests only
    /// dispatchable names — the unknown-command path is reached
    /// from the CLI/IPC socket too, where a Lua-only name would
    /// be a dead-end hint.
    public static func suggestion(
        for unknown: String
    ) -> String? {
        var best: (name: String, distance: Int)?
        for name in dispatchable {
            let distance = editDistance(unknown, name)
            let limit = max(2, unknown.count / 3)
            guard distance <= limit else { continue }
            if best == nil || distance < best!.distance {
                best = (name, distance)
            }
        }
        return best?.name
    }

    /// Levenshtein distance (small inputs only).
    static func editDistance(
        _ a: String,
        _ b: String
    ) -> Int {
        let left = Array(a)
        let right = Array(b)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }
        var previous = Array(0...right.count)
        var current = [Int](
            repeating: 0,
            count: right.count + 1
        )
        for i in 1...left.count {
            current[0] = i
            for j in 1...right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                current[j] = Swift.min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }
}
