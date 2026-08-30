import Foundation

/// launchd service management and crash supervision (`kiwidesk service`)
/// (#342, #196).
public enum ServiceManager {
    public static let label = "org.kiwidesk.KiwiDesk"

    public static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/LaunchAgents/\(label).plist"
            )
    }

    /// Generates LaunchAgent plist content for `executable` (#1068).
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
                <!-- Restart a crash, never a clean exit: the
                     second launch exits SUCCESSFULLY so launchd
                     lets it rest (#1068). Setting this true, or
                     dropping the condition, re-opens an infinite
                     respawn that steals focus every throttle. -->
                <key>SuccessfulExit</key>
                <false/>
            </dict>
        </dict>
        </plist>
        """
    }

    /// Result of a service command operation (#328).
    public struct Outcome {
        public let message: String
        public let ok: Bool

        public init(_ message: String, ok: Bool) {
            self.message = message
            self.ok = ok
        }
    }

    /// Starts or relaunches the LaunchAgent service (#341).
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

    /// Stops and unloads the LaunchAgent service (#328).
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

    /// Boots out and re-bootstraps the LaunchAgent service (#328).
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

    /// Returns human-readable status outcome for CLI (#328, #341).
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

    /// Structured LaunchAgent service status for `AutoStartManager` (#576).
    public static func currentStatus() -> ServiceStatus {
        let (exit, output) = printState()
        return serviceStatus(printExit: exit, output: output)
    }

    /// Parses `launchctl print` exit code and output into `ServiceStatus`
    /// (#341).
    static func serviceStatus(
        printExit: Int32,
        output: String
    ) -> ServiceStatus {
        guard printExit == 0 else {
            return ServiceStatus(isLoaded: false, pid: nil)
        }
        return ServiceStatus(
            isLoaded: true,
            pid: parsePID(from: output)
        )
    }

    /// Action required for `start` based on current launchd state (#341).
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

    /// Formats status message for loaded agent.
    static func statusMessage(pid: Int32?) -> String {
        if let pid {
            return "KiwiDesk service is running (pid \(pid))"
        }
        return "KiwiDesk service is loaded but not running"
    }

    /// Formats restart message distinguishing fresh starts from restarts.
    static func restartMessage(wasLoaded: Bool) -> String {
        wasLoaded
            ? "KiwiDesk service restarted"
            : "KiwiDesk service was not running — started it"
    }

    /// Parses PID from `launchctl print` output.
    static func parsePID(from output: String) -> Int32? {
        for raw in output.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("pid = ") else { continue }
            let value = line.dropFirst("pid = ".count)
                .trimmingCharacters(in: .whitespaces)
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
