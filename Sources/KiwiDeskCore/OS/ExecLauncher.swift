import Foundation
import os

/// Launches external commands without ever blocking the main
/// thread (issue #5): `KiwiDesk.exec` and the async
/// `os.execute` replacement both funnel through here.
///
/// Each command runs as `/bin/sh -c <command>`. The launcher
/// never waits for the child; the optional `onExit` closure is
/// invoked back on the main actor once the child exits, with
/// `(exit_code, stdout, stderr)`. Output pipes are only created
/// when a closure exists, and they are drained via
/// `readabilityHandler` — no thread is ever blocked waiting
/// for a child. The main thread never touches a pipe, so even
/// a child that leaves grandchildren holding the descriptors
/// open can only delay its own callback, never stall the app.
///
/// **Child quit policy:** children are fire-and-forget.
/// `KiwiCore.stop()` does not terminate or wait for them;
/// they are re-parented to launchd and finish naturally.
/// This is intentional — hooks like `sketchybar --notify`
/// should complete even after KiwiDesk exits. Use the optional
/// `timeout` parameter for per-command control.
///
/// The launcher knows nothing about Lua: callers bind their
/// own callback lifetime into `onExit` (see
/// `KiwiCore+ExecAPI`, which captures the owning interpreter
/// weakly so a config reload drops pending callbacks).
@MainActor
public final class ExecLauncher {
    public typealias ExitHandler =
        @MainActor @Sendable (Int32, String, String) -> Void

    public var onLog: @MainActor (String) -> Void = {
        message in
        NSLog("KiwiDesk: %@", message)
    }

    /// Children we have launched and not yet reaped, keyed
    /// by object identity (pids can be recycled). Process
    /// objects must stay alive until termination or their
    /// handlers never fire.
    private var running: [ObjectIdentifier: Process] = [:]

    /// Per-child watchdog tasks, one per `timeout`-carrying
    /// call. Cancelled when the child exits normally.
    private var watchdogs: [ObjectIdentifier: Task<Void, Never>] = [:]

    public init() {}

    /// Number of children that have been launched and not
    /// yet reaped. Exposed in `get_state` as `exec_running`.
    public var runningCount: Int { running.count }

    /// Starts `command` and returns its pid, or nil when the
    /// child could not be spawned.
    ///
    /// If `timeout` is given (seconds), the child receives
    /// SIGTERM after that interval if it has not already
    /// exited; the `onExit` callback is still invoked with
    /// the termination code.
    @discardableResult
    public func launch(
        _ command: String,
        timeout: TimeInterval? = nil,
        onExit: ExitHandler? = nil
    ) -> Int32? {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/bin/sh"
        )
        process.arguments = ["-c", command]
        process.environment = Self.childEnvironment()

        let capture: OutputCapture?
        if onExit != nil {
            let pipes = (out: Pipe(), err: Pipe())
            process.standardOutput = pipes.out
            process.standardError = pipes.err
            capture = OutputCapture(pipes.out, pipes.err)
        } else {
            capture = nil
        }

        // Compute the bookkeeping key before the handler so
        // the handler can close over it directly rather than
        // re-deriving it from the Process object.
        let key = ObjectIdentifier(process)

        // Install before run(): a fast child may exit before
        // launch() returns, and a handler set after the fact
        // would never fire. The main-actor reap cannot race
        // the bookkeeping below — it only runs once launch()
        // has returned control to the main actor.
        process.terminationHandler = { [weak self] child in
            let code = child.terminationStatus
            let deliver: @Sendable (String, String) -> Void = {
                out,
                err in
                Task { @MainActor in
                    self?.reap(
                        key: key,
                        code: code,
                        onExit: onExit,
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
            return nil
        }

        running[key] = process
        capture?.drain()

        if let timeout {
            watchdogs[key] = Task {
                @MainActor [weak self] in
                let ns = UInt64(
                    max(0, timeout) * 1_000_000_000
                )
                try? await Task.sleep(nanoseconds: ns)
                guard !Task.isCancelled else { return }
                guard let self,
                    self.running[key] != nil
                else { return }
                self.running[key]?.terminate()
                self.onLog(
                    "exec: '\(command)' timed out "
                        + "after \(timeout)s"
                )
            }
        }
        return process.processIdentifier
    }

    private func reap(
        key: ObjectIdentifier,
        code: Int32,
        onExit: ExitHandler?,
        stdout: String,
        stderr: String
    ) {
        watchdogs[key]?.cancel()
        watchdogs[key] = nil
        running[key] = nil
        onExit?(code, stdout, stderr)
    }

    /// GUI apps inherit launchd's minimal PATH, not the
    /// user's shell PATH — `sketchybar`, `borders`, etc. live
    /// in the Homebrew prefix and would be "command not
    /// found" in production while working in
    /// terminal-launched dev runs.
    private static func childEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        var parts = (env["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        for extra in ["/opt/homebrew/bin", "/usr/local/bin"]
        where !parts.contains(extra) {
            parts.append(extra)
        }
        env["PATH"] = parts.joined(separator: ":")
        return env
    }
}

/// Drains a child's stdout and stderr via `readabilityHandler`
/// and reports both, off the main thread, once both streams hit
/// EOF. No thread is ever blocked waiting for a pipe; GCD calls
/// the handler as data arrives.
///
/// Each stream is capped at `streamCap` bytes: data beyond the
/// cap is still read (keeping the pipe drained so the child can
/// keep writing without blocking) but discarded after the
/// truncation marker is appended.
private final class OutputCapture: Sendable {
    /// Maximum bytes captured per stream (~1 MB).
    static let streamCap = 1_048_576
    /// Appended once when a stream's cap is reached.
    static let truncMark = Data(
        "\n[output truncated at 1 MB]\n".utf8
    )

    private let out: Pipe
    private let err: Pipe
    private let group = DispatchGroup()
    private let outBuf = OSAllocatedUnfairLock(
        initialState: (data: Data(), capped: false)
    )
    private let errBuf = OSAllocatedUnfairLock(
        initialState: (data: Data(), capped: false)
    )

    init(_ out: Pipe, _ err: Pipe) {
        self.out = out
        self.err = err
        // Enter for both streams up front: the termination
        // handler can fire before drain() runs on the main
        // actor, and an empty group would notify immediately
        // with empty output.
        group.enter()
        group.enter()
    }

    /// Starts both reads; must be called exactly once.
    func drain() {
        attach(out.fileHandleForReading, to: outBuf)
        attach(err.fileHandleForReading, to: errBuf)
    }

    private func attach(
        _ handle: FileHandle,
        to buf: OSAllocatedUnfairLock<
            (
                data: Data, capped: Bool
            )
        >
    ) {
        handle.readabilityHandler = { [group, buf] fh in
            let chunk = fh.availableData
            if chunk.isEmpty {
                // EOF: all write ends of the pipe are closed.
                fh.readabilityHandler = nil
                group.leave()
                return
            }
            buf.withLock { state in
                guard !state.capped else { return }
                let cap = OutputCapture.streamCap
                let space = cap - state.data.count
                if chunk.count <= space {
                    state.data.append(chunk)
                } else {
                    if space > 0 {
                        state.data.append(
                            chunk.prefix(space)
                        )
                    }
                    state.data.append(
                        OutputCapture.truncMark
                    )
                    state.capped = true
                }
            }
        }
    }

    /// Calls `handler` (on a background queue) once both
    /// streams have hit EOF.
    func onComplete(
        _ handler:
            @escaping @Sendable (
                String, String
            ) -> Void
    ) {
        group.notify(
            queue: .global(qos: .utility)
        ) { [outBuf, errBuf] in
            let outData = outBuf.withLock { $0.data }
            let errData = errBuf.withLock { $0.data }
            handler(
                String(decoding: outData, as: UTF8.self),
                String(decoding: errData, as: UTF8.self)
            )
        }
    }
}
