import Foundation

/// Read-only export of KiwiDesk's own unified-log lines (#1209):
/// the `/usr/bin/log show` query a bug report needs — the
/// subsystem, a time range, compact style — written to a file the
/// user chose. It changes nothing about how the log is WRITTEN;
/// `CoreLog` owns that. The Settings export button and any CLI
/// take their arguments from the one derivation here.
public struct LogExport: Sendable {
    /// How far back the export reaches.
    public enum Range: Equatable, Sendable {
        /// The last `seconds`, rounded up to whole minutes for
        /// `log show --last`.
        case last(TimeInterval)
        /// Everything since a moment — KiwiDesk's launch, say.
        case since(Date)
    }

    /// What the export did. `.empty` means the store answered no
    /// line for the range, and no file was written — a file
    /// holding only the tool's header is worse than none.
    public enum Outcome: Equatable, Sendable {
        case written(lines: Int)
        case empty
    }

    public enum Failure: Error, Sendable {
        /// `log show` exited non-zero; `stderr` is its complaint.
        case toolFailed(status: Int32, stderr: String)
        case writeFailed(URL)
    }

    /// One run of the tool: exit status and both streams.
    public struct ToolResult: Sendable {
        public var status: Int32
        public var stdout: Data
        public var stderr: Data

        public init(status: Int32, stdout: Data, stderr: Data) {
            self.status = status
            self.stdout = stdout
            self.stderr = stderr
        }
    }

    /// The tool runner — the live `/usr/bin/log` by default, a
    /// fake in tests so no suite spawns a process (tests.md).
    public var run: @Sendable ([String]) throws -> ToolResult

    public init(
        run: @escaping @Sendable ([String]) throws -> ToolResult =
            LogExport.runLogTool
    ) {
        self.run = run
    }

    /// The `log show` arguments for `range` — the one place the
    /// predicate, the style and the range spelling live.
    public static func arguments(
        for range: Range,
        now: Date = Date()
    ) -> [String] {
        var arguments = [
            "show",
            "--predicate",
            "subsystem == \"\(KiwiLog.subsystem)\"",
            "--style", "compact",
        ]
        switch range {
        case .last(let seconds):
            let minutes = max(1, Int((seconds / 60).rounded(.up)))
            arguments += ["--last", "\(minutes)m"]
        case .since(let start):
            arguments += ["--start", startFormatter.string(from: start)]
        }
        return arguments
    }

    /// Runs the query and writes every line to `destination`.
    public func export(_ range: Range, to destination: URL) throws
        -> Outcome
    {
        let result = try run(Self.arguments(for: range))
        guard result.status == 0 else {
            throw Failure.toolFailed(
                status: result.status,
                stderr: String(decoding: result.stderr, as: UTF8.self)
            )
        }
        let text = String(decoding: result.stdout, as: UTF8.self)
        let lines = Self.logLines(in: text)
        guard lines > 0 else { return .empty }
        do {
            try Data(text.utf8).write(to: destination, options: .atomic)
        } catch {
            throw Failure.writeFailed(destination)
        }
        return .written(lines: lines)
    }

    /// Lines carrying a log entry — the compact style prints a
    /// column header even for an empty range, which is not one.
    static func logLines(in text: String) -> Int {
        text.split(whereSeparator: \.isNewline).filter {
            !$0.hasPrefix("Timestamp")
                && !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }.count
    }

    /// `KiwiDesk-log-2026-09-02-10-15.txt`: sorts by time, safe on
    /// every filesystem, and names the app so a Desktop full of
    /// exports still reads.
    public static func defaultFilename(now: Date = Date()) -> String {
        "KiwiDesk-log-\(filenameFormatter.string(from: now)).txt"
    }

    /// `log show --start` takes local wall-clock time in this shape.
    private static let startFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm"
        return formatter
    }()

    /// The live tool. Blocking — a caller runs it off the main
    /// actor; a two-hour range can take seconds.
    @Sendable
    public static func runLogTool(_ arguments: [String]) throws
        -> ToolResult
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let stdout = out.fileHandleForReading.readDataToEndOfFile()
        let stderr = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ToolResult(
            status: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }
}
