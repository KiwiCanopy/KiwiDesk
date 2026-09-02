import Foundation
import Testing

@testable import KiwiDeskCore

/// The log export (#1209) is read-only over the unified log:
/// one argument derivation (subsystem predicate, compact style,
/// the range spelled the way `log show` takes it), a file written
/// only when the store answered a line, and every failure named.
/// The tool is a seam — no test here spawns `/usr/bin/log`.
@Suite("Log export (#1209)")
struct LogExportTests {
    private static let header =
        "Timestamp               Ty Process[PID:TID]\n"

    private func fake(
        _ stdout: String,
        status: Int32 = 0,
        stderr: String = ""
    ) -> LogExport {
        LogExport { _ in
            LogExport.ToolResult(
                status: status,
                stdout: Data(stdout.utf8),
                stderr: Data(stderr.utf8)
            )
        }
    }

    private func scratch() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-log-\(UUID().uuidString)")
            .appendingPathExtension("txt")
    }

    @Test("the query names the subsystem, compact style and the range")
    func argumentsDeriveFromTheRange() {
        let last = LogExport.arguments(for: .last(15 * 60))
        #expect(last.contains("show"))
        #expect(
            last.contains("subsystem == \"\(KiwiLog.subsystem)\"")
        )
        #expect(last.contains("compact"))
        #expect(last.suffix(2) == ["--last", "15m"])
        // Seconds round UP to whole minutes, never to zero.
        #expect(
            LogExport.arguments(for: .last(61)).suffix(2)
                == ["--last", "2m"]
        )
        #expect(
            LogExport.arguments(for: .last(1)).suffix(2)
                == ["--last", "1m"]
        )
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 9
        parts.day = 2
        parts.hour = 9
        parts.minute = 40
        parts.second = 5
        let start = Calendar.current.date(from: parts)!
        #expect(
            LogExport.arguments(for: .since(start)).suffix(2)
                == ["--start", "2026-09-02 09:40:05"]
        )
    }

    @Test("lines are written to the chosen file and counted")
    func writesTheLines() throws {
        let url = scratch()
        defer { try? FileManager.default.removeItem(at: url) }
        let export = fake(Self.header + "a\nb\nc\n")
        let outcome = try export.export(.last(60), to: url)
        #expect(outcome == .written(lines: 3))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("Timestamp"))
        #expect(text.hasSuffix("c\n"))
    }

    @Test("a range the store answers nothing for writes no file")
    func emptyRangeWritesNothing() throws {
        let url = scratch()
        let export = fake(Self.header)
        #expect(try export.export(.last(60), to: url) == .empty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("the tool's refusal and an unwritable file are named")
    func failuresAreNamed() {
        let url = scratch()
        let refused = fake("", status: 64, stderr: "bad predicate")
        #expect(throws: LogExport.Failure.self) {
            try refused.export(.last(60), to: url)
        }
        do {
            _ = try refused.export(.last(60), to: url)
        } catch let LogExport.Failure.toolFailed(status, stderr) {
            #expect(status == 64)
            #expect(stderr == "bad predicate")
        } catch {
            Issue.record("unexpected \(error)")
        }
        let unwritable = URL(fileURLWithPath: "/dev/null/nope/x.txt")
        let ok = fake(Self.header + "a\n")
        #expect(throws: LogExport.Failure.self) {
            try ok.export(.last(60), to: unwritable)
        }
    }

    @Test("the default filename names the app and sorts by time")
    func defaultFilenameShape() {
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 9
        parts.day = 2
        parts.hour = 10
        parts.minute = 15
        let now = Calendar.current.date(from: parts)!
        #expect(
            LogExport.defaultFilename(now: now)
                == "KiwiDesk-log-2026-09-02-10-15.txt"
        )
    }
}
