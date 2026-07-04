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
            (
                "set_new_window_placement_override",
                "set_new_window_placement_override"
            ),
            ("get_state", "get_state"),
            ("get_layout_info", "get_layout_info"),
            ("list_monitors", "list_monitors"),
            ("debug_log", "debug_log"),
            ("reload_config", "reload_config"),
            ("enable_animations", "enable_animations"),
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
            (
                "set_drag_show_ghost",
                "set_drag_show_ghost"
            ),
            (
                "set_drag_show_drop_zone",
                "set_drag_show_drop_zone"
            ),
            ("help", "help"),
            ("list_commands", "help"),
            ("save_profile", "save_profile"),
            ("load_profile", "load_profile"),
            ("list_profiles", "list_profiles"),
            ("get_profile_status", "get_profile_status"),
            (
                "bind_profile_to_native_space",
                "bind_profile_to_native_space"
            ),
        ]

    /// Layout sub-APIs exposed as global Lua tables.
    public static let namespaces: [String: [String]] = [
        "stack": [
            "promote", "demote",
            "set_master_count", "set_master_ratio",
            "set_overflow_style",
            "set_new_window_placement",
        ],
        "bsp": [
            "set_strategy", "set_ratio",
            "set_new_window_placement",
        ],
        "scroll": [
            "set_width", "set_anchor", "set_speed",
            "set_new_window_placement",
        ],
        "grid": [
            "set_type", "set_fill_empty_space",
            "set_split_direction", "set_dimensions",
            "set_new_window_placement",
        ],
    ]

    /// Every dispatcher-level command name, sorted.
    public static var allCommands: [String] {
        var names = Set(commands.map(\.command))
        for (table, functions) in namespaces {
            for function in functions {
                names.insert("\(table).\(function)")
            }
        }
        names.insert("subscribe")
        return names.sorted()
    }

    /// A close known command for a typo, if any.
    public static func suggestion(
        for unknown: String
    ) -> String? {
        var best: (name: String, distance: Int)?
        for name in allCommands {
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
