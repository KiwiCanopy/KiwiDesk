import Foundation
import os

/// Launches external commands without ever blocking the main
/// thread (issue #5): `KiwiDesk.exec` and the async `os.execute`
/// replacement both funnel through here.
///
/// Each command runs as `/bin/sh -c <command>`. The launcher
/// never waits for the child; an optional Lua callback is
/// invoked back on the main actor once the child exits, with
/// `(exit_code, stdout, stderr)`. Output pipes are only created
/// when a callback exists, and they are drained on a background
/// queue — the main thread never touches a pipe, so even a
/// child that leaves grandchildren holding the descriptors open
/// can only delay its own callback, never stall the app.
@MainActor
public final class ExecLauncher {
    /// Delivers callbacks into the VM. Weak on purpose: a
    /// config reload replaces the interpreter, and pending
    /// callbacks into the torn-down VM must silently drop.
    public weak var lua: LuaInterpreter?

    public var onLog: @MainActor (String) -> Void = { message in
        NSLog("KiwiDesk: %@", message)
    }

    /// Children we have launched and not yet reaped. Process
    /// objects must stay alive until termination or their
    /// handlers never fire.
    private var running: [Int32: Process] = [:]

    public init() {}

    public var runningCount: Int { running.count }

    /// Starts `command` and returns its pid, or nil when the
    /// child could not be spawned. `callbackRef` is a Lua
    /// registry reference; ownership transfers to the launcher,
    /// which releases it after delivery.
    @discardableResult
    public func launch(
        _ command: String,
        callbackRef: Int32? = nil
    ) -> Int32? {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/bin/sh"
        )
        process.arguments = ["-c", command]

        let capture: OutputCapture?
        if callbackRef != nil {
            let pipes = (out: Pipe(), err: Pipe())
            process.standardOutput = pipes.out
            process.standardError = pipes.err
            capture = OutputCapture(pipes.out, pipes.err)
        } else {
            capture = nil
        }

        // Install before run(): a fast child may exit before
        // launch() returns, and a handler set after the fact
        // would never fire. The main-actor reap cannot race
        // the bookkeeping below — it only runs once launch()
        // has returned control to the main actor.
        process.terminationHandler = { [weak self] child in
            let pid = child.processIdentifier
            let code = child.terminationStatus
            let deliver: @Sendable (String, String) -> Void = {
                out,
                err in
                Task { @MainActor in
                    self?.reap(
                        pid: pid,
                        code: code,
                        callbackRef: callbackRef,
                        stdout: out,
                        stderr: err
                    )
                }
            }
            if let capture {
                capture.onComplete(deliver)
            } else {
                deliver("", "")
            }
        }

        do {
            try process.run()
        } catch {
            onLog(
                "exec: failed to start '\(command)': \(error)"
            )
            if let ref = callbackRef {
                lua?.release(ref: ref)
            }
            return nil
        }

        running[process.processIdentifier] = process
        capture?.drain()
        return process.processIdentifier
    }

    private func reap(
        pid: Int32,
        code: Int32,
        callbackRef: Int32?,
        stdout: String,
        stderr: String
    ) {
        running[pid] = nil
        guard let ref = callbackRef else { return }
        guard let lua else { return }
        defer { lua.release(ref: ref) }
        let result = lua.call(
            ref: ref,
            args: [
                .number(Double(code)),
                .string(stdout),
                .string(stderr),
            ]
        )
        if case .failure(let error) = result {
            onLog("exec callback error: \(error)")
        }
    }
}

/// Drains a child's stdout/stderr to end on a background
/// queue and reports both, off the main thread, once both
/// reads hit EOF.
private final class OutputCapture: Sendable {
    private let out: Pipe
    private let err: Pipe
    private let group = DispatchGroup()
    private let collected = OSAllocatedUnfairLock(
        initialState: (out: Data(), err: Data())
    )

    init(_ out: Pipe, _ err: Pipe) {
        self.out = out
        self.err = err
    }

    /// Starts both reads; must be called exactly once.
    func drain() {
        read(out.fileHandleForReading) { [collected] data in
            collected.withLock { $0.out = data }
        }
        read(err.fileHandleForReading) { [collected] data in
            collected.withLock { $0.err = data }
        }
    }

    private func read(
        _ handle: FileHandle,
        _ store: @escaping @Sendable (Data) -> Void
    ) {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            [group] in
            let data = handle.readDataToEndOfFile()
            store(data)
            group.leave()
        }
    }

    /// Calls `handler` (on a background queue) once both
    /// streams are fully read.
    func onComplete(
        _ handler: @escaping @Sendable (String, String) -> Void
    ) {
        group.notify(
            queue: .global(qos: .utility)
        ) { [collected] in
            let (outData, errData) = collected.withLock { $0 }
            handler(
                String(decoding: outData, as: UTF8.self),
                String(decoding: errData, as: UTF8.self)
            )
        }
    }
}
