import CLua
import Foundation

/// A Lua value bridged into Swift.
public indirect enum LuaValue: Sendable, Equatable {
    case none
    case bool(Bool)
    case number(Double)
    case string(String)
    /// Sequential table (1-based array part).
    case array([LuaValue])
    /// Keyed table (string keys only when bridging).
    case table([String: LuaValue])
    /// A Lua function captured as a registry reference.
    /// Call via `LuaInterpreter.call(ref:args:)`; release
    /// with `release(ref:)` when done.
    case functionRef(Int32)

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    public var intValue: Int? {
        numberValue?.finiteInt
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}

/// Stack push/read helpers. All functions expect to run on the
/// thread that owns the Lua state.
enum LuaBridge {
    static func push(_ value: LuaValue, on state: OpaquePointer) {
        switch value {
        case .none:
            lua_pushnil(state)
        case .bool(let b):
            lua_pushboolean(state, b ? 1 : 0)
        case .number(let n):
            lua_pushnumber(state, n)
        case .string(let s):
            lua_pushstring(state, s)
        case .array(let items):
            shim_lua_newtable(state)
            for (index, item) in items.enumerated() {
                push(item, on: state)
                lua_rawseti(state, -2, lua_Integer(index + 1))
            }
        case .table(let dict):
            shim_lua_newtable(state)
            for (key, item) in dict {
                push(item, on: state)
                lua_setfield(state, -2, key)
            }
        case .functionRef(let ref):
            lua_rawgeti(
                state,
                SHIM_LUA_REGISTRYINDEX,
                lua_Integer(ref)
            )
        }
    }

    /// Reads the value at a stack index (non-destructive).
    static func read(
        _ state: OpaquePointer,
        at index: Int32,
        depth: Int = 0
    ) -> LuaValue {
        switch lua_type(state, index) {
        case SHIM_LUA_TBOOLEAN:
            return .bool(lua_toboolean(state, index) != 0)
        case SHIM_LUA_TNUMBER:
            return .number(shim_lua_tonumber(state, index))
        case SHIM_LUA_TSTRING:
            let cString = shim_lua_tostring(state, index)
            return .string(
                cString.map { String(cString: $0) }
                    ?? ""
            )
        case SHIM_LUA_TTABLE where depth < 8:
            return readTable(state, at: index, depth: depth)
        case SHIM_LUA_TFUNCTION:
            // Capture as a registry reference so Swift can
            // call it later (event callbacks, keybindings).
            lua_pushvalue(state, index)
            let ref = luaL_ref(state, SHIM_LUA_REGISTRYINDEX)
            return .functionRef(ref)
        default:
            return .none
        }
    }

    private static func readTable(
        _ state: OpaquePointer,
        at index: Int32,
        depth: Int
    ) -> LuaValue {
        var numbered: [(key: Double, value: LuaValue)] = []
        var dict: [String: LuaValue] = [:]
        let table = lua_absindex(state, index)
        lua_pushnil(state)
        while lua_next(state, table) != 0 {
            let value = read(state, at: -1, depth: depth + 1)
            if lua_type(state, -2) == SHIM_LUA_TNUMBER {
                numbered.append(
                    (shim_lua_tonumber(state, -2), value)
                )
            } else if lua_type(state, -2) == SHIM_LUA_TSTRING,
                let key = shim_lua_tostring(state, -2)
            {
                dict[String(cString: key)] = value
            }
            shim_lua_pop(state, 1)
        }
        numbered.sort { $0.key < $1.key }

        // A pure 1..n sequence is an array; anything else
        // (sparse like `{ [1]=a, [3]=b }`, or mixed keys)
        // becomes a table with canonical string keys.
        let sequential = numbered.enumerated().allSatisfy {
            $0.element.key == Double($0.offset + 1)
        }
        if dict.isEmpty, sequential {
            return .array(numbered.map(\.value))
        }
        for entry in numbered {
            let key =
                entry.key == entry.key.rounded()
                ? String(Int(entry.key))
                : String(entry.key)
            dict[key] = entry.value
        }
        return .table(dict)
    }
}
