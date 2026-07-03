import Foundation

extension JSONValue {
    /// Bridges command results back into Lua.
    var luaValue: LuaValue {
        switch self {
        case .null:
            return .none
        case .bool(let b):
            return .bool(b)
        case .number(let n):
            return .number(n)
        case .string(let s):
            return .string(s)
        case .array(let items):
            return .array(items.map(\.luaValue))
        case .object(let dict):
            return .table(dict.mapValues(\.luaValue))
        }
    }
}

/// Registers the KiwiDesk Lua API (see 04_API_Contract).
///
/// Main commands live on the global `KiwiDesk` table; layout
/// sub-APIs live on `stack`, `bsp`, `scroll`, and `grid`
/// tables, matching the contract examples verbatim.
extension KiwiCore {
    func registerLuaAPI(on lua: LuaInterpreter) {
        // Lua name -> dispatcher command.
        let commands: [(String, String)] = [
            ("focus", "focus"),
            ("swap", "swap"),
            ("focus_space", "focus_virtual_space"),
            ("focus_virtual_space", "focus_virtual_space"),
            ("move_to_space", "move_to_virtual_space"),
            (
                "move_to_virtual_space",
                "move_to_virtual_space"
            ),
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
            ("enable_wake_restore", "enable_wake_restore"),
            (
                "set_wake_restore_delay",
                "set_wake_restore_delay"
            ),
            ("set_drag_ghost", "set_drag_ghost"),
            ("set_drag_drop_zone", "set_drag_drop_zone"),
        ]
        for (luaName, command) in commands {
            register(command, as: luaName, in: "KiwiDesk", lua)
        }

        let namespaces: [String: [String]] = [
            "stack": [
                "promote", "demote",
                "set_master_count", "set_master_ratio",
            ],
            "bsp": ["set_strategy", "set_ratio"],
            "scroll": [
                "set_width", "set_anchor", "set_speed",
            ],
            "grid": [
                "set_type", "set_fill_empty_space",
                "set_split_direction", "set_dimensions",
            ],
        ]
        for (table, functions) in namespaces {
            for function in functions {
                register(
                    "\(table).\(function)",
                    as: function,
                    in: table,
                    lua
                )
            }
        }

        registerEventAPI(on: lua)
    }

    private func register(
        _ command: String,
        as luaName: String,
        in table: String,
        _ lua: LuaInterpreter
    ) {
        lua.register(luaName, in: table) { [weak self] args in
            guard let self else { return .none }
            let response = self.execute(
                command,
                args: args.map(\.jsonValue)
            )
            if let error = response.error {
                self.onLog("\(command): \(error)")
            }
            return response.data?.luaValue ?? .none
        }
    }

    /// `KiwiDesk.on(event, callback)`.
    private func registerEventAPI(on lua: LuaInterpreter) {
        lua.register("on") { [weak self] args in
            guard let self,
                let name = args.first?.stringValue,
                let event = KiwiNotification(rawValue: name),
                case .functionRef(let ref) =
                    args.dropFirst().first ?? .none
            else {
                self?.onLog(
                    "on(): expected event name and function"
                )
                return .none
            }
            self.bus.on(event, ref: ref)
            return .none
        }
    }
}
