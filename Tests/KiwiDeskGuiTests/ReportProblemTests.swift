import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Report a problem's question (#3544): the form opens only after a
/// written log or an explicit "without", the log lands in the
/// handoff folder and the form names it, and the alert maps its
/// buttons and popup to that answer. No test here
/// spawns `/usr/bin/log` or opens a browser.
@Suite("Report a problem (#3544)")
@MainActor
struct ReportProblemTests {
    private static let header =
        "Timestamp               Ty Process[PID:TID]\n"

    private final class Calls {
        var opened: [URL] = []
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
        folder: URL?
    ) -> SettingsModel.ReportHandoff {
        SettingsModel.ReportHandoff(
            folder: folder,
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

    @Test("export writes, then opens the form naming the file")
    func exportWritesThenOpens() async throws {
        let folder = try scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let calls = Calls()
        let problem = await model(answering: Self.header + "a\n")
            .reportProblem(
                answering: .export(.lastHour),
                handoff: handoff(calls, folder: folder)
            )
        #expect(problem == nil)
        let written = try FileManager.default
            .contentsOfDirectory(atPath: folder.path)
        #expect(written.count == 1)
        let name = try #require(written.first)
        #expect(name.hasPrefix("KiwiDesk-log-"))
        #expect(calls.opened.count == 1)
        let shown = (folder.appendingPathComponent(name).path as NSString)
            .abbreviatingWithTildeInPath
        #expect(
            context(calls.opened.first)?.hasSuffix(
                "Log saved as \(shown) — drag it here."
            ) == true
        )
    }

    /// Two exports in one minute share a name; the second takes
    /// `-2` rather than replacing the log the first form names.
    @Test("a second export in the same minute keeps the first")
    func sameMinuteKeepsBoth() throws {
        let folder = try scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = folder.appendingPathComponent("KiwiDesk-log-x.txt")
        #expect(SettingsModel.unused(first) == first)
        try Data().write(to: first)
        #expect(
            SettingsModel.unused(first).lastPathComponent
                == "KiwiDesk-log-x-2.txt"
        )
    }

    @Test("an empty export opens no form")
    func emptyOpensNothing() async throws {
        let folder = try scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let calls = Calls()
        let problem = await model(answering: Self.header)
            .reportProblem(
                answering: .export(.lastHour),
                handoff: handoff(calls, folder: folder)
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
            handoff: handoff(calls, folder: nil)
        )
        #expect(calls.opened.count == 1)
        // Without a log the form names none.
        #expect(context(calls.opened.first)?.contains("Log saved") == false)
        _ = await model.reportProblem(
            answering: .cancel,
            handoff: handoff(calls, folder: nil)
        )
        #expect(calls.opened.count == 1)
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
}
