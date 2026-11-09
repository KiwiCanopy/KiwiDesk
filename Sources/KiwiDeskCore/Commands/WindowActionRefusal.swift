import Foundation

/// Why a window action did nothing, found at perform time — from
/// state or the AX walk (#1518). Core draws the cue itself —
/// nothing crosses into the GUI (#96).
enum WindowActionRefusal: Equatable {
    /// The app has no enabled File ▸ New Window.
    case noNewWindow(app: String)
    /// The window has no enabled close button.
    case noCloseButton(window: String)
    /// `gather` found no window of the app to bring (#1510).
    case nothingToGather(app: String)
    /// Jump to window's Move here cannot move the window into
    /// this Space (#1875): a move the sticky gate stood down, or
    /// an away window the hop cannot reach — no bridge, another
    /// screen's Desktop, unfiled, no census.
    case cannotMoveHere(window: String)
    /// The same verb on a full-screen window: its own macOS Space.
    case cannotMoveHereFullScreen
    /// `move_here` found every matching window already here (#1513).
    case allHere(app: String)
    /// `move_here`'s title text matched no window of the app.
    case noTitleMatch(app: String, text: String)
    /// `move_to_space(_and_follow)` named the Space the window
    /// is already in.
    case alreadyIn(window: String)
    /// A swap named one window twice (#2885).
    case swapWithSelf(window: String)
    /// `swap_here` found no focused window to trade with.
    case nothingHereToSwap
    /// A side is floating: a float holds no slot (#2509).
    case cannotSwapFloating
    /// A side is full screen, in its own macOS Space (#670).
    case cannotSwapFullScreen(window: String)
    /// A Desktop move on a full-screen window, whose macOS Space
    /// is its own (#670, #2888).
    case cannotMoveFullScreen(window: String)
    /// A screen move whose screen shows a full-screen or system
    /// Space, which hides whatever is filed under it (#3117); the
    /// sentence names the full-screen app, the case a user meets.
    case screenShowsFullScreen
    /// A window with no slot to swap, each by what it is (#2885):
    /// the verb's unfiled sides and KiwiHub's rows no verb can see.
    case cannotSwapPocketed
    case cannotSwapUnfiled
    case cannotSwapMinimized
    case cannotSwapHiddenApp
    case cannotSwapHiddenDesktop
    /// KiwiHub's row names a window no longer tracked or listed.
    case cannotSwapGone

    /// The pill's glyph: there is no such action here.
    var pillSymbol: String { "nosign" }

    /// The pill's sentence. It names its subject, by title or by
    /// kind of window, since the pill may draw on the focused window
    /// rather than the target.
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
        case .nothingToGather(let app):
            L(
                "window_action.refusal.nothing_to_gather",
                "No %1$@ window to gather",
                app
            )
        case .cannotMoveHere(let window):
            L(
                "window_action.refusal.cannot_move_here",
                "“%1$@” can't be moved here",
                window
            )
        case .cannotMoveHereFullScreen:
            L(
                "window_action.refusal.cannot_move_here_full_screen",
                "A full-screen window can't be moved here"
            )
        case .allHere(let app):
            L(
                "window_action.refusal.all_here",
                "Every %1$@ window is here",
                app
            )
        case .noTitleMatch(let app, let text):
            L(
                "window_action.refusal.no_title_match",
                "No %1$@ window matches “%2$@”",
                app,
                text
            )
        case .alreadyIn(let window):
            L(
                "window_action.refusal.already_in",
                "“%1$@” is already in that Space",
                window
            )
        case .swapWithSelf(let window):
            L(
                "window_action.refusal.swap_with_self",
                "“%1$@” can't be swapped with itself",
                window
            )
        case .nothingHereToSwap:
            L(
                "window_action.refusal.nothing_here_to_swap",
                "No window here to swap with"
            )
        case .cannotSwapFloating:
            L(
                "window_action.refusal.cannot_swap_floating",
                "A floating window can't be swapped"
            )
        case .cannotSwapFullScreen(let window):
            L(
                "window_action.refusal.cannot_swap_full_screen",
                "“%1$@” is full screen and can't be swapped",
                window
            )
        case .cannotMoveFullScreen(let window):
            L(
                "window_action.refusal.cannot_move_full_screen",
                "“%1$@” is full screen and can't change Desktop",
                window
            )
        case .screenShowsFullScreen:
            L(
                "window_action.refusal.screen_shows_full_screen",
                "A window can't move to a screen showing a full-screen app"
            )
        case .cannotSwapPocketed:
            L(
                "window_action.refusal.cannot_swap_pocketed",
                "A pocketed window can't be swapped"
            )
        case .cannotSwapUnfiled:
            L(
                "window_action.refusal.cannot_swap_unfiled",
                "A window in no Space can't be swapped"
            )
        case .cannotSwapMinimized:
            L(
                "window_action.refusal.cannot_swap_minimized",
                "A minimized window can't be swapped"
            )
        case .cannotSwapHiddenApp:
            L(
                "window_action.refusal.cannot_swap_hidden_app",
                "A hidden app's window can't be swapped"
            )
        case .cannotSwapHiddenDesktop:
            L(
                "window_action.refusal.cannot_swap_hidden_desktop",
                "A window on a hidden Desktop can't be swapped"
            )
        case .cannotSwapGone:
            L(
                "window_action.refusal.cannot_swap_gone",
                "That window is no longer here"
            )
        }
    }

    /// The log line's words — English, like every CLI refusal.
    var logReason: String {
        switch self {
        case .noNewWindow: "no enabled New Window item"
        case .noCloseButton: "no enabled close button"
        case .nothingToGather: "no window to gather"
        case .cannotMoveHere: "cannot move the window here"
        case .cannotMoveHereFullScreen:
            "a full-screen window cannot be moved here"
        case .allHere: "every matching window is already here"
        case .noTitleMatch: "no window title matches"
        case .alreadyIn: "the window is already in that Space"
        case .swapWithSelf: "cannot swap a window with itself"
        case .nothingHereToSwap: "no focused window to swap with"
        case .cannotSwapFloating: "a floating window cannot be swapped"
        case .cannotSwapFullScreen: "a full-screen window cannot be swapped"
        case .cannotMoveFullScreen:
            "a full-screen window cannot change Desktop"
        case .screenShowsFullScreen:
            "a window cannot move to a screen showing a full-screen Space"
        case .cannotSwapPocketed:
            "a pocketed window cannot be swapped"
        case .cannotSwapUnfiled:
            "a window in no Space cannot be swapped"
        case .cannotSwapMinimized:
            "a minimized window cannot be swapped"
        case .cannotSwapHiddenApp:
            "a hidden app's window cannot be swapped"
        case .cannotSwapHiddenDesktop:
            "a window on a hidden Desktop cannot be swapped"
        case .cannotSwapGone: "the window is no longer here"
        }
    }
}
