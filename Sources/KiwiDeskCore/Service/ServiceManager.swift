import Foundation

/// launchd service control (`KiwiDesk service start|stop|
/// restart`). Writes a LaunchAgent referencing the installed
/// binary and drives it via `launchctl bootstrap`/`bootout` —
/// no Homebrew services dependency.
public enum ServiceManager {
    public static let label = "org.kiwidesk.KiwiDesk"

    public static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/LaunchAgents/\(label).plist"
            )
    }

    /// LaunchAgent contents for a given executable path.
    /// Exposed for tests.
    public static func plistContent(
        executable: String
    ) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executable)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
        </dict>
        </plist>
        """
    }

    /// The result of a service verb: a line to print plus whether
    /// it succeeded, so the CLI can map a real launchctl failure
    /// to a non-zero exit while the ordinary already-running /
    /// not-running cases stay exit 0 (#328).
    public struct Outcome {
        public let message: String
        public let ok: Bool

        public init(_ message: String, ok: Bool) {
            self.message = message
            self.ok = ok
        }
    }

    // MARK: - Commands

    /// Bootstraps the agent, relaunches it when the job is loaded
    /// but idle, or no-ops when a process is already running. The
    /// plist is always (re)written first so a moved binary is
    /// picked up on the next `start`.
    ///
    /// The loaded-but-idle case matters: quitting via the quick
    /// menu exits cleanly, and `KeepAlive{SuccessfulExit=false}`
    /// leaves launchd holding the job registered without a process
    /// — a bare `isLoaded()` check would then wrongly report
    /// "already running" and never bring it back (#341).
    public static func start() -> Outcome {
        if let failure = writePlist() {
            return Outcome(failure, ok: false)
        }
        let (status, output) = printState()
        switch startAction(
            loaded: status == 0,
            pid: parsePID(from: output)
        ) {
        case .bootstrap:
            return bootstrap()
        case .kickstart:
            return kickstart()
        case .alreadyRunning:
            return Outcome(
                "KiwiDesk service is already running",
                ok: true
            )
        }
    }

    /// Boots out the agent, or reports cleanly when nothing is
    /// loaded — never leaking launchctl's "re-run as root" noise
    /// for the ordinary not-running case (#328).
    public static func stop() -> Outcome {
        guard isLoaded() else {
            return Outcome(
                "KiwiDesk service is not running",
                ok: true
            )
        }
        let (status, output) = launchctl([
            "bootout", domain, agentURL.path,
        ])
        return status == 0
            ? Outcome("KiwiDesk service stopped", ok: true)
            : Outcome(
                "launchctl bootout failed: \(output)",
                ok: false
            )
    }

    /// The explicit kill-and-relaunch path: boots out any prior
    /// registration (result discarded — it may not be loaded)
    /// and bootstraps fresh.
    ///
    /// Reports honestly whether it actually *restarted* a loaded
    /// job or merely *started* one that wasn't running — a plain
    /// "restarted" would otherwise claim it stopped something that
    /// was never there (matches the loaded-aware wording `start`
    /// and `stop` already give, #328).
    public static func restart() -> Outcome {
        if let failure = writePlist() {
            return Outcome(failure, ok: false)
        }
        let wasLoaded = isLoaded()
        _ = launchctl(["bootout", domain, agentURL.path])
        let started = bootstrap()
        guard started.ok else { return started }
        return Outcome(restartMessage(wasLoaded: wasLoaded), ok: true)
    }

    /// Reports whether the agent is loaded and, if launchd has it
    /// running, its pid. A query — always exit 0.
    public static func status() -> Outcome {
        let (status, output) = printState()
        guard status == 0 else {
            return Outcome(
                "KiwiDesk service is not running",
                ok: true
            )
        }
        return Outcome(
            statusMessage(pid: parsePID(from: output)),
            ok: true
        )
    }

    // MARK: - Helpers (pure — unit-tested)

    /// What `start` must do given the agent's launchd state.
    /// Loaded-but-idle (registered, no pid) means the process was
    /// quit while the job stayed registered, so it is relaunched
    /// rather than reported as already running (#341).
    enum StartAction: Equatable {
        case bootstrap
        case kickstart
        case alreadyRunning
    }

    static func startAction(
        loaded: Bool,
        pid: Int32?
    ) -> StartAction {
        guard loaded else { return .bootstrap }
        return pid != nil ? .alreadyRunning : .kickstart
    }

    /// The `status` line for a loaded agent: names the pid when
    /// launchd is running the process, else flags loaded-but-idle.
    static func statusMessage(pid: Int32?) -> String {
        if let pid {
            return "KiwiDesk service is running (pid \(pid))"
        }
        return "KiwiDesk service is loaded but not running"
    }

    /// The `restart` line: a genuine restart when the job was
    /// already loaded, otherwise a plain start so the CLI never
    /// claims to have stopped a service that wasn't running.
    static func restartMessage(wasLoaded: Bool) -> String {
        wasLoaded
            ? "KiwiDesk service restarted"
            : "KiwiDesk service was not running — started it"
    }

    /// Extracts the `pid = N` line from `launchctl print` output.
    static func parsePID(from output: String) -> Int32? {
        for raw in output.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("pid = ") else { continue }
            let value = line.dropFirst("pid = ".count)
                .trimmingCharacters(in: .whitespaces)
            // Keep scanning if this line's value is malformed
            // rather than giving up on the whole output.
            if let pid = Int32(value) { return pid }
        }
        return nil
    }

    // MARK: - launchctl

    private static var domain: String {
        "gui/\(getuid())"
    }

    /// True when launchd has the agent loaded in this GUI domain.
    private static func isLoaded() -> Bool {
        printState().status == 0
    }

    private static func printState() -> (
        status: Int32, output: String
    ) {
        launchctl(["print", "\(domain)/\(label)"])
    }

    private static func bootstrap() -> Outcome {
        let (status, output) = launchctl([
            "bootstrap", domain, agentURL.path,
        ])
        return status == 0
            ? Outcome("KiwiDesk service started", ok: true)
            : Outcome(
                "launchctl bootstrap failed: \(output)",
                ok: false
            )
    }

    /// Relaunches an already-loaded but idle job in place (#341) —
    /// the job stays registered, launchd just spawns the process
    /// again.
    private static func kickstart() -> Outcome {
        let (status, output) = launchctl([
            "kickstart", "\(domain)/\(label)",
        ])
        return status == 0
            ? Outcome("KiwiDesk service started", ok: true)
            : Outcome(
                "launchctl kickstart failed: \(output)",
                ok: false
            )
    }

    /// (Re)writes the LaunchAgent plist. Returns an error message
    /// on failure, `nil` on success.
    private static func writePlist() -> String? {
        let executable =
            Bundle.main.executableURL?.path
            ?? CommandLine.arguments[0]
        do {
            try FileManager.default.createDirectory(
                at: agentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try plistContent(executable: executable).write(
                to: agentURL,
                atomically: true,
                encoding: .utf8
            )
            return nil
        } catch {
            return "failed to write LaunchAgent: \(error)"
        }
    }

    private static func launchctl(
        _ arguments: [String]
    ) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/bin/launchctl"
        )
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (1, "\(error)")
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading
            .readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (
            process.terminationStatus,
            output.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
    }
}
