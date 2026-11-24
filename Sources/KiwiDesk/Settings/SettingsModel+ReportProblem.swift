import AppKit
import KiwiDeskCore

/// Report a problem (#3214, #3544): the footer's door to the bug
/// form, on Home and in Simple alike. It asks first whether to
/// export a log, because Simple has no Log row; nothing is
/// uploaded, and the user's drag into the form stays the consent.
/// The log goes where the user's save panel puts it, and the form
/// asks for it rather than Finder revealing it: activating Finder
/// can switch the user's Desktop.
extension SettingsModel {
    /// Where the footer's export lands — the user's pick, nil on
    /// Cancel — and how the form opens.
    struct ReportHandoff {
        var pick: @MainActor () -> URL?
        var open: @MainActor (URL) -> Void

        static let live = ReportHandoff(
            pick: { SettingsModel.pickLogFile() },
            open: { NSWorkspace.shared.open($0) }
        )
    }

    /// Asks over the Settings window, then acts on the answer. A
    /// problem shows in an alert over that window and opens no
    /// form; it is this path's own presenter, beside the Log row's
    /// SwiftUI alert, since only this one has no row to sit on.
    func reportProblem() async {
        guard !isExportingLog, !ReportProblemPrompt.isAsking,
            let window = SettingsWindowController.openWindow
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
            // Cancel in the save panel writes and opens nothing.
            guard let url = handoff.pick() else { return nil }
            if let problem = await runLogExport(choice.range, to: url) {
                return problem
            }
            handoff.open(report.formURL(logSaved: true))
            return nil
        }
    }
}
