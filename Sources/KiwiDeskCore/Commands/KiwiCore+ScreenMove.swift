import Foundation

/// `move_to_display_last`, `move_to_display <direction>` and their
/// `_and_follow` forms (#3117): the focused window moves into the
/// Space another screen shows, through `move_to_space`'s own move.
/// The screen is the one `focus_display*` would go to.
extension KiwiCore {
    /// `move_to_display_last(_and_follow)`: the screen the focus
    /// was on before. A follow files the arrival in the screen
    /// history, so pressing it again sends the window back.
    func moveToDisplayLast(follow: Bool) -> CommandResponse {
        noteSpaceVisits()
        guard let target = lastScreen() else {
            bumpAtScreenEdge(.right)
            return .fail("no other screen")
        }
        return moveToScreen(target, follow: follow)
    }

    /// `move_to_display(_and_follow) <direction>`: the nearest
    /// screen that way, through the one `screenAhead`.
    func moveToDisplay(
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = Direction(rawValue: raw)
        else { return .expected(Direction.self) }
        guard let target = screenAhead(direction) else {
            bumpAtScreenEdge(direction)
            return .fail("no screen \(raw) of focus")
        }
        return moveToScreen(target, follow: follow)
    }

    /// Files the focused window into the Space `display` shows. A
    /// screen on a native full-screen or system Space takes no
    /// window, since that Space hides whatever is filed under it.
    private func moveToScreen(
        _ display: DisplayID,
        follow: Bool
    ) -> CommandResponse {
        guard let window = focusedWindowID else {
            return .fail("no focused window")
        }
        if let refusal = spaceMoveRefusal(window) { return refusal }
        guard screenShowsUserSpace(on: display) else {
            let refusal = WindowActionRefusal.screenShowsFullScreen
            cueWindowAction(refusal, on: window)
            return .fail(refusal.logReason)
        }
        guard let shown = state.workspaces.activeSpace(on: display) else {
            return .fail("no Space on that screen")
        }
        return moveToSpace(window, shown, follow: follow)
    }
}
