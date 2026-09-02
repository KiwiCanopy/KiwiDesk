import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The export's model half (#1209), driven through the `logExport`
/// seam past the save panel: the run's outcome lands on the MODEL
/// — a problem for the alert, nothing on success — and the
/// in-progress flag is down again when it returns, so a user who
/// navigated away mid-run still meets the outcome. No test here
/// spawns `/usr/bin/log`.
@Suite("Log export model (#1209)")
@MainActor
struct LogExportModelTests {
    private static let header =
        "Timestamp               Ty Process[PID:TID]\n"

    private func model(
        answering stdout: String,
        status: Int32 = 0
    ) -> SettingsModel {
        let model = makeTestModel()
        model.logExport = LogExport { _ in
            LogExport.ToolResult(
                status: status,
                stdout: Data(stdout.utf8),
                stderr: Data()
            )
        }
        return model
    }

    private func scratch() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-log-model-\(UUID().uuidString)")
            .appendingPathExtension("txt")
    }

    @Test("a written export leaves no problem and lowers the flag")
    func successIsSilent() async {
        let url = scratch()
        defer { try? FileManager.default.removeItem(at: url) }
        let model = model(answering: Self.header + "a\n")
        await model.exportLog(.last(60), to: url)
        #expect(model.logExportProblem == nil)
        #expect(!model.isExportingLog)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("an empty range and a refused tool land as problems")
    func problemsLandOnTheModel() async {
        let url = scratch()
        defer { try? FileManager.default.removeItem(at: url) }
        let empty = model(answering: Self.header)
        await empty.exportLog(.last(60), to: url)
        #expect(empty.logExportProblem == .empty)
        #expect(!empty.isExportingLog)
        let refused = model(answering: "", status: 64)
        await refused.exportLog(.last(60), to: url)
        #expect(refused.logExportProblem == .toolFailed)
        // Dismissing clears it, as the alert binding does.
        refused.logExportProblem = nil
        #expect(refused.logExportProblem == nil)
    }
}
