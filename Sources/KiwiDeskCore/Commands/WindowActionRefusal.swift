import Foundation

/// Why `new_window` or `close_window` did nothing, found only once
/// the AX walk ran (#1518): the menu offers the rows from state
/// alone, so they refuse at perform time instead of greying.
/// Core draws the cue itself — nothing crosses into the GUI (#96).
enum WindowActionRefusal: Equatable {
    /// The app has no enabled File ▸ New Window.
    case noNewWindow(app: String)
    /// The window has no enabled close button.
    case noCloseButton(window: String)

    /// The pill's glyph: there is no such action here.
    var pillSymbol: String { "nosign" }

    /// The pill's sentence. It names its subject, since the pill
    /// may draw on the focused window rather than the target.
    @MainActor
    var sentence: String {
        switch self {
        case .noNewWindow(let app):
            L(
                "window_action.refusal.no_new_window",
                "%1$@ has no New Window command",
                app
            )
        case .noCloseButton(let window):
            L(
                "window_action.refusal.no_close_button",
                "“%1$@” has no close button",
                window
            )
        }
    }

    /// The log line's words — English, like every CLI refusal.
    var logReason: String {
        switch self {
        case .noNewWindow: "no enabled New Window item"
        case .noCloseButton: "no enabled close button"
        }
    }
}
