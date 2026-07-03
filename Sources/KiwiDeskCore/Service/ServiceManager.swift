import Foundation

/// launchd service control (`KiwiDesk service start|stop|
/// restart`). Writes a LaunchAgent referencing the installed
/// binary and drives it via `launchctl bootstrap`/`bootout` —
/// no Homebrew services dependency (see 04_API_Contract §10).
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

    // MARK: - Commands

    public static func start() -> String {
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
        } catch {
            return "failed to write LaunchAgent: \(error)"
        }
        // A previous registration blocks bootstrap.
        _ = launchctl(["bootout", domain, agentURL.path])
        let (status, output) = launchctl([
            "bootstrap", domain, agentURL.path,
        ])
        return status == 0
            ? "KiwiDesk service started"
            : "launchctl bootstrap failed: \(output)"
    }

    public static func stop() -> String {
        let (status, output) = launchctl([
            "bootout", domain, agentURL.path,
        ])
        return status == 0
            ? "KiwiDesk service stopped"
            : "launchctl bootout failed: \(output)"
    }

    public static func restart() -> String {
        let stopped = stop()
        let started = start()
        return "\(stopped)\n\(started)"
    }

    // MARK: - launchctl

    private static var domain: String {
        "gui/\(getuid())"
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
