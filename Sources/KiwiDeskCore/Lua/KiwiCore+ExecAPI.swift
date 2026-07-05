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
///
/// `exec` is deliberately Lua-only, like `bind` and `on`: its
/// callback cannot cross the JSON socket, and exposing shell
/// execution on the IPC socket would let any client with file
/// access to it run commands under KiwiDesk's identity (and
/// its Accessibility grant). Do not add it to the dispatcher.
extension KiwiCore {
    func registerExecAPI(on lua: LuaInterpreter) {
        lua.register("exec") { [weak self, weak lua] args in
            let callbackRef: Int32?
            if case .functionRef(let ref) =
                args.dropFirst().first ?? .none
            {
                callbackRef = ref
            } else {
                callbackRef = nil
            }
            guard let self,
                let command = args.first?.stringValue,
                !command.isEmpty
            else {
                // The trampoline already took registry refs
                // on any function arguments; don't leak them.
                for case .functionRef(let ref) in args {
                    lua?.release(ref: ref)
                }
                self?.onLog(
                    "exec(): expected a command string"
                )
                return .none
            }
            var onExit: ExecLauncher.ExitHandler?
            if let ref = callbackRef {
                // Bind the ref to the VM that minted it: on a
                // config reload the weak capture goes nil and
                // the callback drops silently. A ref must
                // never reach a different VM's registry —
                // its slot may already belong to an unrelated
                // function there.
                onExit = {
                    [weak self, weak lua] code, out, err in
                    guard let lua else { return }
                    defer { lua.release(ref: ref) }
                    let result = lua.call(
                        ref: ref,
                        args: [
                            .number(Double(code)),
                            .string(out),
                            .string(err),
                        ]
                    )
                    if case .failure(let error) = result {
                        self?.onLog(
                            "exec callback error: \(error)"
                        )
                    }
                }
            }
            guard
                let pid = self.exec.launch(
                    command,
                    onExit: onExit
                )
            else {
                if let ref = callbackRef {
                    lua?.release(ref: ref)
                }
                return .none
            }
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
