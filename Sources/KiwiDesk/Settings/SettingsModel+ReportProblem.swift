import AppKit
import KiwiDeskCore

/// Report a problem (#3214, #3544): the footer's door to the bug
/// form, on Home and in Simple alike. It asks first whether to
/// export a log, because Simple has no Log row; nothing is
/// uploaded, and the user's drag into the form stays the consent.
/// The form names the saved file rather than Finder revealing it:
/// activating Finder can switch the user's Desktop.
extension SettingsModel {
    /// Where the footer's export lands with no save panel.
    struct ReportHandoff {
        var folder: URL?
        var open: @MainActor (URL) -> Void

        static let live = ReportHandoff(
            folder: FileManager.default.urls(
                for: .downloadsDirectory,
                in: .userDomainMask
            ).first,
            open: { NSWorkspace.shared.open($0) }
        )
    }

    /// Asks over the Settings window, then acts on the answer; a
    /// problem is shown over that window and opens no form.
    func reportProblem() async {
        guard !isExportingLog,
            let window = NSApp.windows.first(where: {
                $0.delegate is SettingsWindowController
            })
        else { return }
        let answer = await ReportProblemPrompt.ask(over: window)
        guard
            let problem = await reportProblem(
                answering: answer,
                handoff: .live
            )
        else { return }
        let alert = NSAlert()
        alert.messageText = LogExportText.title(for: problem)
        alert.informativeText = LogExportText.sentence(for: problem)
        alert.beginSheetModal(for: window) { _ in }
    }

    /// The form opens only after a written log or an explicit
    /// "without"; returns what stopped the export, if anything.
    func reportProblem(
        answering answer: ReportProblemPrompt.Answer,
        handoff: ReportHandoff
    ) async -> LogExportProblem? {
        let report = core.problemReport
        switch answer {
        case .cancel:
            return nil
        case .withoutLog:
            handoff.open(report.formURL)
            return nil
        case .export(let choice):
            let name = LogExport.defaultFilename()
            guard let folder = handoff.folder else {
                return .writeFailed(URL(fileURLWithPath: name))
            }
            let url = folder.appendingPathComponent(name)
            if let problem = await runLogExport(choice.range, to: url) {
                return problem
            }
            handoff.open(report.formURL(logFile: name))
            return nil
        }
    }
}
