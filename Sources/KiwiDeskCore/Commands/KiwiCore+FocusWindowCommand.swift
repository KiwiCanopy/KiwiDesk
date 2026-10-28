import Foundation

/// `focus_window <window>` (#2492): focuses a window by the id
/// `list_windows` and `get_state` report, on the Space it draws on
/// — another Space switches through the Space Bar's own pick,
/// landing on it. Where that pick would fall back to a bare switch
/// (a Desktop no screen shows), the verb refuses with the reason
/// instead. Ambient motion, like every CLI verb.
extension KiwiCore {
    func focusWindowCommand(_ args: [JSONValue]) -> CommandResponse {
        guard let first = args.first, first != .null else {
            return .fail("expected window id")
        }
        switch commandTarget("focus_window", args) {
        case .refused(let response): return response
        case .window(let id):
            if state.isPocketed(id) {
                return takePocketOut(id)
                    ? .ok() : .fail("pocket is unreachable")
            }
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
            if let space = state.renderSpace(of: window),
                space != state.workspaces.activeSpace
            {
                focusFromSpaceBar(id, on: space)
            } else {
                focusWindow(id, warp: true)
            }
            return .ok()
        }
    }
}
