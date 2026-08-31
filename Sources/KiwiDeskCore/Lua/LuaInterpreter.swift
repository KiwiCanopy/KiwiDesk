import CLua
import Foundation

public enum LuaError: Error, Equatable {
    case initializationFailed
    /// Syntax or runtime failure, including sandbox timeouts.
    case runtime(String)
}

/// Boxed Swift closure callable from Lua.
private final class FunctionBox {
    let fn: @MainActor ([LuaValue]) -> LuaValue

    init(_ fn: @escaping @MainActor ([LuaValue]) -> LuaValue) {
        self.fn = fn
    }
}

/// C trampoline: recovers the box from the closure's upvalue,
/// bridges arguments, and pushes the result. Runs while the VM
/// executes on the main thread.
private func trampoline(_ state: OpaquePointer?) -> Int32 {
    guard let state,
        let pointer = lua_touserdata(
            state,
            shim_lua_upvalueindex(1)
        )
    else { return 0 }
    // The VM only ever runs on the main thread; the box is
    // MainActor-owned in practice.
    nonisolated(unsafe) let box = Unmanaged<FunctionBox>
        .fromOpaque(pointer)
        .takeUnretainedValue()
    var args: [LuaValue] = []
    let argc = lua_gettop(state)
    if argc > 0 {
        for index in 1...argc {
            args.append(LuaBridge.read(state, at: index))
        }
    }
    let result = MainActor.assumeIsolated { box.fn(args) }
    if case .none = result {
        return 0
    }
    LuaBridge.push(result, on: state)
    return 1
}

/// Embedded Lua 5.5 VM hosting user configuration and scripts.
///
/// Runs on MainActor; execution is bounded by an instruction count hook
/// enforcing `timeout`. Callbacks disable on error (`EventBus`,
/// `KeybindingManager`).
@MainActor
public final class LuaInterpreter {
    /// Budget per VM entry, in seconds.
    public var timeout: TimeInterval = 0.5

    private nonisolated(unsafe) var state: OpaquePointer?
    private var boxes: [FunctionBox] = []

    public init?() {
        guard let created = luaL_newstate() else { return nil }
        shim_luaL_openlibs(created)
        shim_enable_timeout_hook(created, 10_000)
        state = created
    }

    deinit {
        if let state {
            lua_close(state)
        }
    }

    @discardableResult
    public func run(_ code: String) -> Result<Void, LuaError> {
        guard let state else {
            return .failure(.initializationFailed)
        }
        guard luaL_loadstring(state, code) == SHIM_LUA_OK
        else {
            return .failure(.runtime(popError(state)))
        }
        return protectedCall(state, argc: 0)
    }

    @discardableResult
    public func runFile(
        _ url: URL
    ) -> Result<Void, LuaError> {
        guard let state else {
            return .failure(.initializationFailed)
        }
        guard
            luaL_loadfilex(state, url.path, nil) == SHIM_LUA_OK
        else {
            return .failure(.runtime(popError(state)))
        }
        return protectedCall(state, argc: 0)
    }

    /// Compiles `body` as a Lua function and returns registry ref
    /// (`KeybindingManager.reset()`, `KeybindingManager.fire`).
    public func makeFunction(
        body: String
    ) -> Result<Int32, LuaError> {
        guard let state else {
            return .failure(.initializationFailed)
        }
        let src = "return function()\n\(body)\nend"
        guard luaL_loadstring(state, src) == SHIM_LUA_OK else {
            return .failure(.runtime(popError(state)))
        }
        shim_set_deadline(
            state,
            shim_monotonic_now() + timeout
        )
        defer { shim_set_deadline(state, 0) }
        guard shim_lua_pcall(state, 0, 1, 0) == SHIM_LUA_OK
        else {
            return .failure(.runtime(popError(state)))
        }
        let ref = luaL_ref(state, SHIM_LUA_REGISTRYINDEX)
        return .success(ref)
    }

    /// Calls a Lua function previously captured as a registry reference
    /// (`LuaValue.functionRef`).
    @discardableResult
    public func call(
        ref: Int32,
        args: [LuaValue] = []
    ) -> Result<Void, LuaError> {
        guard let state else {
            return .failure(.initializationFailed)
        }
        lua_rawgeti(
            state,
            SHIM_LUA_REGISTRYINDEX,
            lua_Integer(ref)
        )
        guard shim_lua_isfunction(state, -1) != 0 else {
            shim_lua_pop(state, 1)
            return .failure(.runtime("stale function ref"))
        }
        for arg in args {
            LuaBridge.push(arg, on: state)
        }
        return protectedCall(state, argc: Int32(args.count))
    }

    /// Releases a captured function reference.
    public func release(ref: Int32) {
        guard let state else { return }
        luaL_unref(state, SHIM_LUA_REGISTRYINDEX, ref)
    }

    /// Returns chunk name and 1-based line range for function ref (#4).
    public func functionSource(
        ref: Int32
    ) -> (source: String, firstLine: Int, lastLine: Int)? {
        guard let state else { return nil }
        var first: Int32 = 0
        var last: Int32 = 0
        guard
            let cString = shim_func_source(
                state,
                ref,
                &first,
                &last
            )
        else { return nil }
        return (String(cString: cString), Int(first), Int(last))
    }

    // MARK: - Registration

    /// Exposes a Swift closure as `tableName.name(...)`. The
    /// global table is created on first use.
    public func register(
        _ name: String,
        in tableName: String = "KiwiDesk",
        _ fn: @escaping @MainActor ([LuaValue]) -> LuaValue
    ) {
        guard let state else { return }
        ensureGlobalTable(tableName)
        let box = FunctionBox(fn)
        boxes.append(box)
        lua_pushlightuserdata(
            state,
            Unmanaged.passUnretained(box).toOpaque()
        )
        lua_pushcclosure(state, trampoline, 1)
        lua_setfield(state, -2, name)
        shim_lua_pop(state, 1)
    }

    /// Reads a global variable.
    public func global(_ name: String) -> LuaValue {
        guard let state else { return .none }
        lua_getglobal(state, name)
        defer { shim_lua_pop(state, 1) }
        return LuaBridge.read(state, at: -1)
    }

    // MARK: - Internals

    private func ensureGlobalTable(_ name: String) {
        guard let state else { return }
        lua_getglobal(state, name)
        if shim_lua_istable(state, -1) == 0 {
            shim_lua_pop(state, 1)
            shim_lua_newtable(state)
            lua_pushvalue(state, -1)
            lua_setglobal(state, name)
        }
    }

    private func protectedCall(
        _ state: OpaquePointer,
        argc: Int32
    ) -> Result<Void, LuaError> {
        shim_set_deadline(
            state,
            shim_monotonic_now() + timeout
        )
        defer { shim_set_deadline(state, 0) }
        guard shim_lua_pcall(state, argc, 0, 0) == SHIM_LUA_OK
        else {
            return .failure(.runtime(popError(state)))
        }
        return .success(())
    }

    private func popError(_ state: OpaquePointer) -> String {
        defer { shim_lua_pop(state, 1) }
        guard let message = shim_lua_tostring(state, -1) else {
            return "unknown Lua error"
        }
        return String(cString: message)
    }
}
