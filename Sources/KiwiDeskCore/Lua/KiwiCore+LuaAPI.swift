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
        installTypoGuard(on: lua)
    }

    /// A metatable on the KiwiDesk table turns typo'd calls
    /// ("attempt to call a nil value") into a helpful log
    /// line pointing at KiwiDesk.help().
    private func installTypoGuard(on lua: LuaInterpreter) {
        lua.run(
            """
            setmetatable(KiwiDesk, {
                __index = function(_, key)
                    return function()
                        KiwiDesk.debug_log(
                            "unknown KiwiDesk function '"
                            .. tostring(key)
                            .. "' — see KiwiDesk.help()")
                    end
                end,
            })
            """
        )
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
