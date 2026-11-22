import AppKit
import KiwiDeskCore

/// Report a problem's one question (#3544): export a log first, or
/// continue without. An `NSAlert` sheet over Settings with the
/// time range as its accessory popup.
@MainActor
enum ReportProblemPrompt {
    enum Answer: Equatable {
        case export(SettingsModel.LogExportRange)
        case withoutLog
        case cancel
    }

    /// The range each open starts on (#3544).
    static let defaultRange = SettingsModel.LogExportRange.lastHour

    /// True while the question is up, so a second click asks
    /// nothing.
    private(set) static var isAsking = false

    /// Asks over `window` and returns the answer.
    static func ask(over window: NSWindow) async -> Answer {
        isAsking = true
        defer { isAsking = false }
        let (alert, popup) = alert()
        let response = await withCheckedContinuation { done in
            alert.beginSheetModal(for: window) { done.resume(returning: $0) }
        }
        return answer(response, picked: popup.indexOfSelectedItem)
    }

    /// The alert and its range popup.
    static func alert() -> (NSAlert, NSPopUpButton) {
        let alert = NSAlert()
        alert.messageText = L(
            "report.log.title",
            "Include a log with your report?"
        )
        alert.informativeText = L(
            "report.log.message",
            "A log helps find the cause, and lists the settings you "
                + "changed. It is saved to Downloads; drag it into the "
                + "form if you want it public."
        )
        alert.addButton(withTitle: L("report.log.export", "Export Log"))
        alert.addButton(
            withTitle: L("report.log.without", "Continue Without Log")
        )
        let cancel = alert.addButton(
            withTitle: L("report.log.cancel", "Cancel")
        )
        // A translated title is not AppKit's own "Cancel", which
        // alone gets Escape for free.
        cancel.keyEquivalent = "\u{1b}"
        let (accessory, popup) = rangePicker()
        alert.accessoryView = accessory
        return (alert, popup)
    }

    /// The answer for `response`, the popup's item index `picked`.
    static func answer(
        _ response: NSApplication.ModalResponse,
        picked: Int
    ) -> Answer {
        switch response {
        case .alertFirstButtonReturn:
            let ranges = SettingsModel.LogExportRange.allCases
            return .export(
                ranges.indices.contains(picked)
                    ? ranges[picked] : defaultRange
            )
        case .alertSecondButtonReturn:
            return .withoutLog
        default:
            return .cancel
        }
    }

    private static func rangePicker() -> (NSView, NSPopUpButton) {
        let label = NSTextField(
            labelWithString: L("report.log.range", "Time range:")
        )
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        let ranges = SettingsModel.LogExportRange.allCases
        popup.addItems(withTitles: ranges.map(\.title))
        popup.selectItem(at: ranges.firstIndex(of: defaultRange) ?? 0)
        popup.setAccessibilityLabel(
            L("general.advanced.log.range", "Time range")
        )
        let stack = NSStackView(views: [label, popup])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.frame.size = stack.fittingSize
        return (stack, popup)
    }

    /// What stopped the export, for this path's alert. A write
    /// failure has its own sentence: no save panel offers another
    /// folder here.
    static func sentence(for problem: LogExportProblem) -> String {
        guard case .writeFailed = problem else {
            return LogExportText.sentence(for: problem)
        }
        return L(
            "report.log.write_failed",
            "KiwiDesk couldn't save the log to your Downloads folder. "
                + "Check that it exists and has free space, then try "
                + "again."
        )
    }
}
