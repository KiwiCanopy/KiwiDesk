import Foundation
import os

/// Launches external commands non-blockingly via `/bin/sh -c` (#5).
/// Children are fire-and-forget; callbacks and timeouts run asynchronously.
@MainActor
public final class ExecLauncher {
    public typealias ExitHandler =
        @MainActor @Sendable (Int32, String, String) -> Void

    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// Launched child process, command string, and optional timeout watchdog.
    private struct Child {
        let process: Process
        let command: String
        var watchdog: Task<Void, Never>?
    }

    /// Active children keyed by ObjectIdentifier (avoiding pid reuse).
    private var running: [ObjectIdentifier: Child] = [:]

    /// In-flight tally per command for `dedup` (#467).
    private var inFlight: [String: Int] = [:]

    /// Warning threshold for outstanding children (#467).
    private static let warnThreshold = 20

    /// Latch for `warnThreshold` warning (#467).
    private var highWaterWarned = false

    public init() {}

    /// Number of children currently active and un-reaped (`exec_running`).
    public var runningCount: Int { running.count }

    /// Starts `command` returning child pid or nil on failure (#467, #489).
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
            // Null device avoids holding test runner pipes open (#489).
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            capture = nil
        }

        let key = ObjectIdentifier(process)

        // Install before run(): a fast child may exit before
        // launch() returns, and a handler set after the fact would
        // never fire.
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

    /// Grace period after SIGTERM before force-reaping (seconds).
    private static let reapGrace: TimeInterval = 2

    /// Creates timeout watchdog sending SIGTERM and force-reaping on grace
    /// (#37).
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

    /// Cancels timeout watchdogs on teardown without killing
    /// children — a `timeout` armed before a mid-session stop must
    /// not SIGTERM after management tore down. Accepted trade: a
    /// child ALREADY stuck at that instant leaks its `running`
    /// entry for the process life (its command stays
    /// dedup-blocked); clearing here would be worse — a later EOF
    /// reap would find no entry and leak its Lua callback ref.
    func cancelWatchdogs() {
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
        // Idempotent: the EOF path and the timeout force-reap can
        // both target the same child; whichever runs first wins,
        // so `onExit` (which releases the Lua ref) fires exactly
        // once.
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

    /// Augments environment PATH with Homebrew directories.
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
