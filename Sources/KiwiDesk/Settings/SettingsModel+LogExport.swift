import AppKit
import KiwiDeskCore

/// Export the log from Settings (#1209) — rung zero of General ▸
/// Advanced's recovery ladder, because it changes nothing. Read-only
/// over the unified log; the query is `LogExport`'s.
extension SettingsModel {
    /// The ranges the control offers — presets only, never a
    /// custom field (#1209; `docs/design-decisions.md` ▸ Recovery
    /// escape hatches). Per-mount view state, never a setting.
    enum LogExportRange: String, CaseIterable, Identifiable {
        case last15Minutes
        case lastHour
        case sinceLaunch

        var id: String { rawValue }

        /// `sinceLaunch` is THIS process's launch — a crash
        /// relaunch excludes the crash, which is the macOS crash
        /// report's job. The current process always has a launch
        /// date; the hour is a stand-in for a nil that does not
        /// occur, chosen over a trap.
        var range: LogExport.Range {
            switch self {
            case .last15Minutes: return .last(15 * 60)
            case .lastHour: return .last(60 * 60)
            case .sinceLaunch:
                return .since(
                    NSRunningApplication.current.launchDate
                        ?? Date(timeIntervalSinceNow: -60 * 60)
                )
            }
        }

        @MainActor var title: String {
            switch self {
            case .last15Minutes:
                return L(
                    "general.advanced.log.range.last_15m",
                    "Last 15 minutes"
                )
            case .lastHour:
                return L(
                    "general.advanced.log.range.last_1h",
                    "Last hour"
                )
            case .sinceLaunch:
                return L(
                    "general.advanced.log.range.since_launch",
                    "Since KiwiDesk started"
                )
            }
        }
    }

    /// Asks where to save FIRST — the ellipsis promises a dialog
    /// now, and the query is the slow part — then runs it off the
    /// main actor and stays silent on success, as the backup
    /// export does: the panel was the confirmation. A problem
    /// lands in `logExportProblem` for the section's alert; the
    /// model holds it so a user who navigates away mid-run still
    /// meets the outcome.
    func exportLog(_ choice: LogExportRange) async {
        // Semantic re-entry refusal (a queued second press, an
        // `AXPress` past the modal panel) — the button stays
        // enabled, so focus never leaves it.
        guard !isExportingLog else { return }
        isExportingLog = true
        defer { isExportingLog = false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = LogExport.defaultFilename()
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        await exportLog(choice.range, to: url)
    }

    /// The run itself, split from the panel so a test can drive
    /// it through the `logExport` seam (`LogExportModelTests`).
    func exportLog(_ range: LogExport.Range, to url: URL) async {
        let export = logExport
        isExportingLog = true
        defer { isExportingLog = false }
        let outcome = await Task.detached(priority: .userInitiated) {
            Result { () throws(LogExport.Failure) in
                try export.export(range, to: url)
            }
        }.value
        switch outcome {
        case .success(.written):
            break
        case .success(.empty):
            logExportProblem = .empty
        case .failure(let failure):
            logExportProblem = LogExportProblem(failure)
        }
    }
}
