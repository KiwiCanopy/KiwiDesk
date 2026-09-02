import AppKit
import KiwiDeskCore

/// Export the log from Settings (#1209) — rung zero of General ▸
/// Advanced's recovery ladder, because it changes nothing. Read-only
/// over the unified log; the query is `LogExport`'s.
extension SettingsModel {
    /// The ranges the control offers — presets only (ui-designer,
    /// 2026-09-02): a reporter who needs forty minutes takes the
    /// hour, a superset the maintainer trims for free, while a
    /// custom field adds a parser and a refusal in ten locales.
    /// Per-mount view state, never a stored setting.
    enum LogExportRange: String, CaseIterable, Identifiable {
        case last15Minutes
        case lastHour
        case sinceLaunch

        var id: String { rawValue }

        /// `sinceLaunch` is THIS process's launch — a crash
        /// relaunch excludes the crash, which is the macOS crash
        /// report's job, not this log's.
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
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = LogExport.defaultFilename()
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        let range = choice.range
        let export = logExport
        isExportingLog = true
        defer { isExportingLog = false }
        let outcome = await Task.detached(priority: .userInitiated) {
            Result { try export.export(range, to: url) }
        }.value
        switch outcome {
        case .success(.written):
            break
        case .success(.empty):
            logExportProblem = .empty
        case .failure(let failure as LogExport.Failure):
            logExportProblem = LogExportProblem(failure)
        case .failure:
            logExportProblem = .toolFailed
        }
    }
}
