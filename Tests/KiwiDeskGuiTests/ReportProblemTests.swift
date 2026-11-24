import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Report a problem's question (#3544): the form opens only after a
/// written log or an explicit "without", the log lands where the
/// save panel's pick says and the form asks for it, a cancelled
/// pick writes and opens nothing, and the alert maps its buttons
/// and popup to that answer. No test here spawns `/usr/bin/log`,
/// shows a save panel or opens a browser.
@Suite("Report a problem (#3544)")
@MainActor
struct ReportProblemTests {
    private static let header =
        "Timestamp               Ty Process[PID:TID]\n"

    private final class Calls {
        var opened: [URL] = []
        var picks = 0
        var busyAtPick: Bool?
    }

    private func context(_ url: URL?) -> String? {
        URLComponents(
            url: url ?? URL(fileURLWithPath: "/"),
            resolvingAgainstBaseURL: false
        )?.queryItems?.first { $0.name == "extra_context" }?.value
    }

    private func model(answering stdout: String) -> SettingsModel {
        let model = makeTestModel()
        model.logExport = LogExport { _ in
            LogExport.ToolResult(
                status: 0,
                stdout: Data(stdout.utf8),
                stderr: Data()
            )
        }
        return model
    }

    private func handoff(
        _ calls: Calls,
        picking file: URL?,
        model: SettingsModel? = nil
    ) -> SettingsModel.ReportHandoff {
        SettingsModel.ReportHandoff(
            pick: {
                calls.picks += 1
                calls.busyAtPick = model?.isExportingLog
                return file
            },
            open: { calls.opened.append($0) }
        )
    }

    private func scratchFolder() throws -> URL {
        let url = testTemporaryDirectory.appendingPathComponent(
            "kiwi-report-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    @Test("export writes the pick, then opens the form asking for it")
    func exportWritesThenOpens() async throws {
        let folder = try scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("picked.txt")
        let calls = Calls()
        let problem = await model(answering: Self.header + "a\n")
            .reportProblem(
                answering: .export(.lastHour),
                handoff: handoff(calls, picking: file)
            )
        #expect(problem == nil)
        #expect(calls.picks == 1)
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(calls.opened.count == 1)
        #expect(
            context(calls.opened.first)?.hasSuffix(ProblemReport.logLine)
                == true
        )
    }

    /// Cancel in the save panel is the user stopping: no form
    /// opens.
    @Test("a cancelled pick opens nothing")
    func cancelledPickOpensNothing() async {
        let calls = Calls()
        let model = model(answering: Self.header + "a\n")
        let problem = await model.reportProblem(
            answering: .export(.lastHour),
            handoff: handoff(calls, picking: nil, model: model)
        )
        #expect(problem == nil)
        #expect(calls.picks == 1)
        #expect(calls.opened.isEmpty)
        // The footer and the Log row refuse while the panel is up,
        // and take presses again once it closes.
        #expect(calls.busyAtPick == true)
        #expect(!model.isExportingLog)
    }

    @Test("an empty export opens no form")
    func emptyOpensNothing() async throws {
        let folder = try scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let calls = Calls()
        let problem = await model(answering: Self.header)
            .reportProblem(
                answering: .export(.lastHour),
                handoff: handoff(
                    calls,
                    picking: folder.appendingPathComponent("empty.txt")
                )
            )
        #expect(problem == .empty)
        #expect(calls.opened.isEmpty)
    }

    @Test("without opens the form alone; Cancel does nothing")
    func withoutAndCancel() async {
        let calls = Calls()
        let model = model(answering: Self.header + "a\n")
        _ = await model.reportProblem(
            answering: .withoutLog,
            handoff: handoff(calls, picking: nil)
        )
        #expect(calls.opened.count == 1)
        // Without a log the form asks for none, and no panel shows.
        #expect(
            context(calls.opened.first)?.contains(ProblemReport.logLine)
                == false
        )
        _ = await model.reportProblem(
            answering: .cancel,
            handoff: handoff(calls, picking: nil)
        )
        #expect(calls.opened.count == 1)
        #expect(calls.picks == 0)
    }

    @Test("the buttons and popup map to the answer")
    func alertAnswers() {
        let (alert, popup) = ReportProblemPrompt.alert()
        #expect(alert.buttons.count == 3)
        #expect(alert.buttons[0].keyEquivalent == "\r")
        #expect(alert.buttons[2].keyEquivalent == "\u{1b}")
        let ranges = SettingsModel.LogExportRange.allCases
        #expect(ranges[popup.indexOfSelectedItem] == .lastHour)
        let first = ReportProblemPrompt.answer(
            .alertFirstButtonReturn,
            picked: popup.indexOfSelectedItem
        )
        #expect(first == .export(.lastHour))
        #expect(
            ReportProblemPrompt.answer(.alertFirstButtonReturn, picked: 0)
                == .export(ranges[0])
        )
        #expect(
            ReportProblemPrompt.answer(.alertSecondButtonReturn, picked: 0)
                == .withoutLog
        )
        #expect(
            ReportProblemPrompt.answer(.alertThirdButtonReturn, picked: 0)
                == .cancel
        )
        // A quit ends the sheet as `.cancel` (`QuitSheets`).
        #expect(ReportProblemPrompt.answer(.cancel, picked: 0) == .cancel)
    }

    @Test("the footer link greys while a log exports")
    func footerIsWired() throws {
        let source = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Home/HomeSupportStrip.swift"
                )
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            source.occurrences(of: ".disabled(model.isExportingLog)") == 1
        )
    }

    /// The live handoff asks through the shared save panel; every
    /// other test fakes the pick, so only this sees a write past it.
    @Test("the live handoff picks through the save panel")
    func liveHandoffAsks() throws {
        let source = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/"
                        + "SettingsModel+ReportProblem.swift"
                )
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            source.occurrences(
                of: "pick:{SettingsModel.pickLogFile()}"
            ) == 1
        )
        #expect(source.occurrences(of: "logFolder") == 0)
    }
}
