import Foundation

/// `focus_window <window>` (#2492): focuses a window by the id
/// `list_windows` and `get_state` report, through the pick a bar
/// row takes — a window on another Space switches there, landing
/// on it. Ambient motion, like every CLI verb.
extension KiwiCore {
    func focusWindowCommand(_ args: [JSONValue]) -> CommandResponse {
        guard let first = args.first, first != .null else {
            return .fail("expected window id")
        }
        switch commandTarget("focus_window", args) {
        case .refused(let response): return response
        case .window(let id):
            guard let window = state.windows[id] else {
                return .fail("unknown window: \(id.raw)")
            }
            // A full-screen window keeps a macOS Space of its own,
            // which no KiwiDesk switch reaches (#670).
            guard !window.isFullscreen else {
                return .fail("window \(id.raw) is full screen")
            }
            guard !raiseCrossesDesktops(id) else {
                return .fail(
                    "window \(id.raw) is on a Desktop no screen shows"
                )
            }
            let space = state.workspaces.space(of: id)
            if let space, space != state.workspaces.activeSpace,
                !window.isSticky
            {
                focusFromSpaceBar(id, on: space)
            } else {
                focusWindow(id, warp: true)
            }
            return .ok()
        }
    }
}
