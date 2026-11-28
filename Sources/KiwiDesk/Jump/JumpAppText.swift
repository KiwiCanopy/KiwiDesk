import Foundation
import KiwiDeskCore

/// The words of KiwiHub's Applications section (#3704): its header,
/// a row's state, what VoiceOver hears and a refused open.
@MainActor
enum JumpAppText {
    /// The section's header.
    static var header: String {
        L("jump.section.applications", "Applications")
    }

    /// A row's right-hand label.
    static func state(_ app: JumpAppCandidate) -> String {
        app.running
            ? L("jump.app.open_no_windows", "Open, no windows")
            : L("jump.app.not_open", "Not open")
    }

    /// The row as VoiceOver reads it.
    static func spoken(_ app: JumpAppCandidate) -> String {
        app.running
            ? L(
                "jump.app.ax.open_no_windows",
                "%1$@, application, open, no windows",
                app.name
            )
            : L(
                "jump.app.ax.not_open",
                "%1$@, application, not open",
                app.name
            )
    }

    /// The reason a refused open shows in the row.
    static func refused(_ block: JumpOpenBlock) -> String {
        switch block {
        case .notFound: L("jump.app.not_found", "Not found")
        }
    }

    /// What VoiceOver hears for a refused open.
    static func refusedSpoken(
        _ app: JumpAppCandidate,
        _ block: JumpOpenBlock
    ) -> String {
        switch block {
        case .notFound:
            L("jump.app.ax.not_found", "Can't open: %1$@", app.name)
        }
    }

    /// The list's line where neither a window nor an app matches.
    static var noResults: String {
        L("jump.empty.no_results", "No Results")
    }

    /// ↩'s hint while an app row is selected.
    static var footerOpen: String {
        L("jump.footer.open", "%1$@ Open", "↩")
    }
}
