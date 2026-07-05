import Foundation

/// `KiwiDesk.exec` and the non-blocking `os.execute` bridge
/// (issue #5).
///
/// The Lua VM runs synchronously on the main thread, and the
/// runaway-script guard is an instruction-count hook — a
/// callback blocking inside a C call (`system()`, pipe reads)
/// executes zero VM instructions, so the hook can never fire
/// and the whole app freezes. External commands therefore must
/// always go through `ExecLauncher`, which backgrounds them.
extension KiwiCore {
    func registerExecAPI(on lua: LuaInterpreter) {
        exec.lua = lua
        exec.onLog = { [weak self] message in
            self?.onLog(message)
        }
        lua.register("exec") { [weak self] args in
            guard let self,
                let command = args.first?.stringValue,
                !command.isEmpty
            else {
                self?.onLog(
                    "exec(): expected a command string"
                )
                return .none
            }
            var ref: Int32?
            if case .functionRef(let found) =
                args.dropFirst().first ?? .none
            {
                ref = found
            }
            guard
                let pid = self.exec.launch(
                    command,
                    callbackRef: ref
                )
            else { return .none }
            return .number(Double(pid))
        }
        neutralizeBlockingOSCalls(on: lua)
    }

    /// Rewrites the stdlib entry points that block in C where
    /// the instruction-count watchdog cannot interrupt them:
    /// `os.execute` becomes fire-and-forget via `exec`, and
    /// `io.popen` is disabled outright (its synchronous
    /// read-the-output contract cannot be honored without
    /// blocking).
    private func neutralizeBlockingOSCalls(
        on lua: LuaInterpreter
    ) {
        lua.run(
            """
            local launch = KiwiDesk.exec
            local warned = false
            os.execute = function(command)
                if command == nil then return true end
                if not warned then
                    warned = true
                    KiwiDesk.debug_log(
                        "os.execute runs asynchronously in "
                        .. "KiwiDesk; use KiwiDesk.exec(cmd, "
                        .. "callback) for exit codes")
                end
                launch(command)
                return true
            end
            io.popen = function()
                return nil, "io.popen is disabled (it "
                    .. "blocks the app); use KiwiDesk.exec("
                    .. "cmd, callback) instead"
            end
            """
        )
    }
}
