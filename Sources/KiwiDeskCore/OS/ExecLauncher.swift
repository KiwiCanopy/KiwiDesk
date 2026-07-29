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

    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// A launched child and its optional timeout watchdog, kept
    /// together so the two can never desync — one table, one
    /// count. The `Process` must stay alive until termination or
    /// its handlers never fire. `command` is kept so the reap can
    /// find and decrement this child's in-flight tally.
    private struct Child {
        let process: Process
        let command: String
        var watchdog: Task<Void, Never>?
    }

    /// Children we have launched and not yet reaped, keyed by
    /// object identity (pids can be recycled).
    private var running: [ObjectIdentifier: Child] = [:]

    /// In-flight count per exact command string, powering the
    /// `dedup` skip (#467). A wedged receiver (e.g. a sketchybar
    /// daemon that never answers) otherwise lets per-event hook
    /// pokes pile up without bound; deduping caps it at one stuck
    /// child per distinct command. Reference-counted so a
    /// legitimately-parallel non-deduped launch of the same
    /// command still tears down cleanly.
    private var inFlight: [String: Int] = [:]

    /// `runningCount` value at which `launch` warns that a hook
    /// command may be hanging (#467). Discoverable without polling
    /// `get_state.exec_running`.
    private static let warnThreshold = 20

    /// One-shot latch for the `warnThreshold` warning: set when the
    /// outstanding count first reaches the threshold, re-armed once
    /// it falls back below. Without it a monotonic pile-up (the
    /// #467 scenario) would warn only on the single `== threshold`
    /// launch and a count flapping across the line would re-warn
    /// every crossing.
    private var highWaterWarned = false

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
    ///
    /// When `dedup` is true and an identical `command` string is
    /// already in flight, the spawn is skipped and nil returned
    /// (the caller releases any callback ref, as on a failed
    /// spawn). For trigger-style pokes that just re-poke a
    /// receiver this is correct semantics — a second poke while
    /// one is pending adds nothing — and it bounds accumulation
    /// against a wedged receiver (#467). `dedup` defaults to
    /// `false` here (a raw, policy-free primitive); the opinionated
    /// default-on lives at the Lua boundary in `KiwiCore+ExecAPI`.
    @discardableResult
    public func launch(
        _ command: String,
        timeout: TimeInterval? = nil,
        dedup: Bool = false,
        onExit: ExitHandler? = nil
    ) -> Int32? {
        if dedup, (inFlight[command] ?? 0) > 0 {
            onLog(
                "exec: skipped duplicate in-flight command "
                    + "'\(command)'"
            )
            return nil
        }
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
            // Fire-and-forget: nobody reads the output, so give
            // the child the null device instead of letting it
            // inherit ours. An inherited pipe outlives us in a
            // long-lived child (a wedged `sketchybar --trigger`),
            // and whoever reads our stdout then waits for an EOF
            // that never comes — the #489 test-runner hang, where
            // the child held the swiftpm runner's pipe hostage.
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
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

        running[key] = Child(process: process, command: command)
        inFlight[command, default: 0] += 1
        if running.count >= Self.warnThreshold, !highWaterWarned {
            highWaterWarned = true
            onLog(
                "exec: \(running.count) children outstanding — "
                    + "a hook command may be hanging"
            )
        }
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
    ///
    /// Trade-off: this also voids the force-reap for a child that
    /// is *already stuck* (grandchild holding the pipe, so EOF
    /// never arrives) when the stop fires — its `running` entry
    /// then leaks for the life of the process (`exec` outlives a
    /// stop/start), inflating `runningCount` and (its `inFlight`
    /// tally riding along) keeping that exact command deduped
    /// away — even if the receiver later recovers, so a
    /// transiently-wedged command can stay dedup-blocked for the
    /// process life. Accepted (documented as a limitation): the
    /// window is tiny (a stop must fire while a child holds the
    /// pipe past EOF), and clearing the entries here would be
    /// wrong — a later EOF `reap` of that child would then find no
    /// entry and leak its Lua callback ref. Avoiding a
    /// post-teardown SIGTERM outweighs the corner.
    func cancelWatchdogs() {
        // Snapshot the keys: the loop mutates `running`.
        for key in Array(running.keys) {
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
        if let n = inFlight[child.command], n > 1 {
            inFlight[child.command] = n - 1
        } else {
            inFlight[child.command] = nil
        }
        if running.count < Self.warnThreshold {
            highWaterWarned = false
        }
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
