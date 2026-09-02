import Foundation
import KiwiDeskCore

/// What stopped a log export (#1209) — Core's cases, the GUI's
/// sentences (#96). `writeFailed` reuses the backup export's
/// write sentence: same meaning, ten translations saved.
enum LogExportProblem: Equatable {
    /// The store answered no KiwiDesk line for the range.
    case empty
    /// `log show` refused; its stderr is machine text and never
    /// reaches the user.
    case toolFailed
    case writeFailed(URL)

    init(_ failure: LogExport.Failure) {
        switch failure {
        case .toolFailed: self = .toolFailed
        case .writeFailed(let url): self = .writeFailed(url)
        }
    }
}

@MainActor
enum LogExportText {
    static func title(for problem: LogExportProblem) -> String {
        switch problem {
        case .empty:
            return L(
                "general.advanced.log.error.empty_title",
                "Nothing to Export"
            )
        case .toolFailed:
            return L(
                "general.advanced.log.error.tool_title",
                "Couldn't Export the Log"
            )
        case .writeFailed:
            return L(
                "general.advanced.log.error.write_title",
                "Couldn't Save the Log"
            )
        }
    }

    static func sentence(for problem: LogExportProblem) -> String {
        switch problem {
        case .empty:
            return L(
                "general.advanced.log.error.empty",
                "The log has no KiwiDesk entries in that time "
                    + "range. Pick a longer range, or make the "
                    + "problem happen again and export then."
            )
        case .toolFailed:
            return L(
                "general.advanced.log.error.tool",
                "macOS didn't hand over the log. Try again in a "
                    + "moment."
            )
        case .writeFailed(let url):
            // The backup export's write sentence, deliberately
            // shared (`SetupBackupText`).
            return L(
                "general.advanced.backup.error.write_failed",
                "KiwiDesk couldn't write “%1$@”. Try somewhere "
                    + "else, like your Desktop.",
                url.lastPathComponent
            )
        }
    }
}
