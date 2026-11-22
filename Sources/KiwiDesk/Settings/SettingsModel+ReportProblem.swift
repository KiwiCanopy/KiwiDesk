import AppKit
import KiwiDeskCore

/// Report a problem (#3214, #3544): the footer's door to the bug
/// form, on Home and in Simple alike. It asks first whether to
/// export a log, because Simple has no Log row; nothing is
/// uploaded, and the user's drag into the form stays the consent.
/// The form names the saved file rather than Finder revealing it:
/// activating Finder can switch the user's Desktop.
extension SettingsModel {
    /// Where the footer's export lands, with no save panel, and
    /// how the form opens.
    struct ReportHandoff {
        var folder: URL?
        var open: @MainActor (URL) -> Void

        static let live = ReportHandoff(
            folder: SettingsModel.logFolder,
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
        alert.informativeText = ReportProblemPrompt.sentence(for: problem)
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
            let url = Self.unused(folder.appendingPathComponent(name))
            if let problem = await runLogExport(choice.range, to: url) {
                return problem
            }
            let shown = (url.path as NSString).abbreviatingWithTildeInPath
            handoff.open(report.formURL(logFile: shown))
            return nil
        }
    }

    /// `url`, or the first `name-2.txt`, `name-3.txt`… beside it
    /// that does not exist yet: the export writes atomically and
    /// would replace a log from the same minute.
    static func unused(_ url: URL) -> URL {
        let files = FileManager.default
        guard files.fileExists(atPath: url.path) else { return url }
        let stem = url.deletingPathExtension().lastPathComponent
        let folder = url.deletingLastPathComponent()
        var n = 2
        while true {
            let next = folder.appendingPathComponent(
                "\(stem)-\(n).\(url.pathExtension)"
            )
            if !files.fileExists(atPath: next.path) { return next }
            n += 1
        }
    }
}
