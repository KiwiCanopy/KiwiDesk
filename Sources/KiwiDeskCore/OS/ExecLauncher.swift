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
/// `KiwiCore.stop()` neither terminates nor waits for them —
/// they re-parent to launchd and finish on their own. This is
/// intentional: hooks like `sketchybar --notify` should
/// complete even as KiwiDesk quits. Note `stop()` also runs
/// mid-session on an AX-permission revoke (after which
/// `start()` may reuse this same launcher), so it calls
/// `cancelWatchdogs()` — a `timeout` armed before the stop must
/// not SIGTERM a child once management has torn down. Use the
/// optional `timeout` parameter for per-command control.
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

    /// A launched child and its optional timeout watchdog, kept
    /// together so the two can never desync — one table, one
    /// count. The `Process` must stay alive until termination or
    /// its handlers never fire.
    private struct Child {
        let process: Process
        var watchdog: Task<Void, Never>?
    }

    /// Children we have launched and not yet reaped, keyed by
    /// object identity (pids can be recycled).
    private var running: [ObjectIdentifier: Child] = [:]

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

        running[key] = Child(process: process)
        capture?.drain()

        if let timeout {
            running[key]?.watchdog = makeWatchdog(
                key: key,
                command: command,
                timeout: timeout,
                capture: capture,
                onExit: onExit
            )
        }
        return process.processIdentifier
    }

    /// Grace after SIGTERM for the normal EOF-driven reap to
    /// land before the watchdog force-reaps (seconds).
    private static let reapGrace: TimeInterval = 2

    /// Builds a timeout watchdog: SIGTERM at `timeout`, then a
    /// short grace for the normal EOF-driven reap to land. If the
    /// child is still un-reaped after that — e.g. it left a
    /// grandchild holding the output pipe open, so EOF never
    /// arrives — force-reap with whatever was captured, so the
    /// bookkeeping entry and any Lua callback ref are released
    /// instead of leaking (#37 review).
    private func makeWatchdog(
        key: ObjectIdentifier,
        command: String,
        timeout: TimeInterval,
        capture: OutputCapture?,
        onExit: ExitHandler?
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: Self.nanos(timeout)
            )
            guard !Task.isCancelled, let self,
                self.running[key] != nil
            else { return }
            self.running[key]?.process.terminate()
            self.onLog(
                "exec: '\(command)' timed out after "
                    + "\(timeout)s"
            )
            try? await Task.sleep(
                nanoseconds: Self.nanos(Self.reapGrace)
            )
            guard !Task.isCancelled,
                self.running[key] != nil
            else { return }
            let (out, err) = capture?.snapshot() ?? ("", "")
            self.reap(
                key: key,
                code: 128 + SIGTERM,
                onExit: onExit,
                stdout: out,
                stderr: err
            )
        }
    }

    private static func nanos(
        _ seconds: TimeInterval
    ) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000)
    }

    /// Cancels outstanding timeout watchdogs without disturbing
    /// the children. Called from `KiwiCore.stop()`: a `timeout`
    /// armed before a mid-session stop (AX-permission revoke,
    /// which may `start()` again on this same launcher) must not
    /// SIGTERM or force-reap a child after teardown. Children
    /// stay fire-and-forget.
    func cancelWatchdogs() {
        for key in running.keys {
            running[key]?.watchdog?.cancel()
            running[key]?.watchdog = nil
        }
    }

    private func reap(
        key: ObjectIdentifier,
        code: Int32,
        onExit: ExitHandler?,
        stdout: String,
        stderr: String
    ) {
        // Idempotent: the normal EOF path and the timeout
        // force-reap can both target the same child. Whichever
        // runs first wins; the other finds no entry and is a
        // no-op — so `onExit` (which releases the Lua ref) fires
        // exactly once. Both run on the main actor, so the
        // check-and-clear can't interleave.
        guard let child = running[key] else { return }
        child.watchdog?.cancel()
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
