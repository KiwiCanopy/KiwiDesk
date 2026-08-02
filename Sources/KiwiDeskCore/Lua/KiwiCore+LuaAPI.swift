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

/// Registers the KiwiDesk Lua API.
///
/// Main commands live on the global `KiwiDesk` table; layout
/// sub-APIs live on `stack`, `bsp`, `scroll`, and `grid`
/// tables.
extension KiwiCore {
    func registerLuaAPI(on lua: LuaInterpreter) {
        for entry in APIReference.commands {
            register(
                entry.command,
                as: entry.lua,
                in: "KiwiDesk",
                lua
            )
        }
        for (table, functions) in APIReference.namespaces {
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
        registerKeybindingAPI(on: lua)
        registerUIAPI(on: lua)
        registerExecAPI(on: lua)
        installTypoGuards(on: lua)
    }

    /// UI-bridge verbs that cross Core → GUI (#330). They carry no
    /// dispatcher `CommandResponse` — they raise a `@MainActor`
    /// hook the app wires to a window — so, like `bind`/`on`, they
    /// live outside `APIReference.commands` and are listed in
    /// `luaOnly` for `help()`. The VM never holds the UI ref.
    private func registerUIAPI(on lua: LuaInterpreter) {
        lua.register("show_shortcuts") { [weak self] _ in
            self?.onShowShortcuts()
            return .none
        }
    }

    /// `KiwiDesk.bind`, `define_layer`, and `switch_layer`.
    private func registerKeybindingAPI(
        on lua: LuaInterpreter
    ) {
        lua.register("bind") { [weak self] args in
            guard let self,
                let text = args.first?.stringValue,
                let combo = KeyCombo.parse(text),
                case .functionRef(let ref) =
                    args.dropFirst().first ?? .none
            else {
                self?.onLog(
                    "bind(): expected combo and function"
                )
                return .none
            }
            self.keys.bind(combo, ref: ref)
            return .none
        }
        lua.register("define_layer") { [weak self] args in
            guard let self,
                let name = args.first?.stringValue,
                case .table(let table) =
                    args.dropFirst().first ?? .none
            else {
                self?.onLog(
                    "define_layer(): expected name and table"
                )
                return .none
            }
            var bindings: [KeyCombo: Int32] = [:]
            for (key, value) in table {
                guard let combo = KeyCombo.parse(key),
                    case .functionRef(let ref) = value
                else {
                    self.onLog(
                        "define_layer('\(name)'): bad key "
                            + "'\(key)'"
                    )
                    continue
                }
                bindings[combo] = ref
            }
            let icon = Self.modeIcon(
                from: args.dropFirst(2).first
            )
            self.keys.defineLayer(
                name,
                bindings: bindings,
                icon: icon
            )
            return .none
        }
        lua.register("switch_layer") { [weak self] args in
            guard let name = args.first?.stringValue else {
                self?.onLog(
                    "switch_layer(): expected layer name"
                )
                return .none
            }
            self?.keys.switchLayer(name)
            return .none
        }
    }

    /// Reads `{ icon = "..." }` from `define_layer`'s optional
    /// third argument.
    private static func modeIcon(
        from value: LuaValue?
    ) -> String? {
        guard case .table(let opts)? = value else {
            return nil
        }
        return opts["icon"]?.stringValue
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
