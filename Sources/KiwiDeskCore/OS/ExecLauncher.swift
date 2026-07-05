import Foundation
import os

/// Launches external commands without ever blocking the main
/// thread (issue #5): `KiwiDesk.exec` and the async `os.execute`
/// replacement both funnel through here.
///
/// Each command runs as `/bin/sh -c <command>`. The launcher
/// never waits for the child; the optional `onExit` closure is
/// invoked back on the main actor once the child exits, with
/// `(exit_code, stdout, stderr)`. Output pipes are only created
/// when a closure exists, and they are drained on a background
/// queue — the main thread never touches a pipe, so even a
/// child that leaves grandchildren holding the descriptors open
/// can only delay its own callback, never stall the app.
///
/// The launcher knows nothing about Lua: callers bind their own
/// callback lifetime into `onExit` (see `KiwiCore+ExecAPI`,
/// which captures the owning interpreter weakly so a config
/// reload drops pending callbacks).
@MainActor
public final class ExecLauncher {
    public typealias ExitHandler =
        @MainActor @Sendable (Int32, String, String) -> Void

    public var onLog: @MainActor (String) -> Void = { message in
        NSLog("KiwiDesk: %@", message)
    }

    /// Children we have launched and not yet reaped, keyed by
    /// object identity (pids can be recycled). Process objects
    /// must stay alive until termination or their handlers
    /// never fire.
    private var running: [ObjectIdentifier: Process] = [:]

    public init() {}

    public var runningCount: Int { running.count }

    /// Starts `command` and returns its pid, or nil when the
    /// child could not be spawned.
    @discardableResult
    public func launch(
        _ command: String,
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

        // Install before run(): a fast child may exit before
        // launch() returns, and a handler set after the fact
        // would never fire. The main-actor reap cannot race
        // the bookkeeping below — it only runs once launch()
        // has returned control to the main actor.
        process.terminationHandler = { [weak self] child in
            let key = ObjectIdentifier(child)
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

        running[ObjectIdentifier(process)] = process
        capture?.drain()
        return process.processIdentifier
    }

    private func reap(
        key: ObjectIdentifier,
        code: Int32,
        onExit: ExitHandler?,
        stdout: String,
        stderr: String
    ) {
        running[key] = nil
        onExit?(code, stdout, stderr)
    }

    /// GUI apps inherit launchd's minimal PATH, not the user's
    /// shell PATH — `sketchybar`, `borders`, etc. live in the
    /// Homebrew prefix and would be "command not found" in
    /// production while working in terminal-launched dev runs.
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
        // Enter for both streams up front: the termination
        // handler can fire before drain() runs on the main
        // actor, and an empty group would notify immediately
        // with empty output.
        group.enter()
        group.enter()
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
        DispatchQueue.global(qos: .utility).async {
            [group] in
            // readToEnd throws on I/O errors; the legacy
            // readDataToEndOfFile raises an ObjC exception
            // Swift cannot catch.
            store((try? handle.readToEnd()) ?? Data())
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
