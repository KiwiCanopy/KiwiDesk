import Foundation

/// Why `new_window`, `close_window` or a bar list's row did
/// nothing, found only at perform time (#1518, #1946): the lists
/// offer their rows from state alone, so they refuse when picked
/// instead of greying.
/// Core draws the cue itself — nothing crosses into the GUI (#96).
enum WindowActionRefusal: Equatable {
    /// The app has no enabled File ▸ New Window.
    case noNewWindow(app: String)
    /// The window has no enabled close button.
    case noCloseButton(window: String)
    /// A bar list's row names a window on a Desktop no display
    /// shows; focusing it would switch Desktops (#1345, #1946).
    case onAnotherDesktop(window: String)

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
        case .onAnotherDesktop(let window):
            L(
                "window_action.refusal.on_another_desktop",
                "“%1$@” is on another Desktop",
                window
            )
        }
    }

    /// The log line's words — English, like every CLI refusal.
    var logReason: String {
        switch self {
        case .noNewWindow: "no enabled New Window item"
        case .noCloseButton: "no enabled close button"
        case .onAnotherDesktop: "bar row on an unshown Desktop"
        }
    }
}
