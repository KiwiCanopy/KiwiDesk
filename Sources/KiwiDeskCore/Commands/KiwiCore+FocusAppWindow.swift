import Foundation

/// `focus_app_window(direction)` (#3131): focus the frontmost
/// app's next or previous window wherever it lives — another
/// Space, another display, a Desktop nobody shows. One step of
/// the ring Open or Focus's repeat press walks
/// (`cycleAppWindow`); this file never builds a ring of its own.
/// Minimized windows are not in the ring and are never restored
/// (#673).
extension KiwiCore {
    func focusAppWindow(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = ModeCycleDirection(rawValue: raw)
        else { return .expected(ModeCycleDirection.self) }
        guard
            let current = state.workspaces.lastFocused,
            let bundleID = state.windows[current]?
                .appBundleID?.lowercased()
        else { return .fail("no focused window") }
        guard
            cycleAppWindow(
                bundleID: bundleID,
                direction: direction,
                verb: "focus_app_window"
            )
        else {
            return .fail("the focused app has no other window to focus")
        }
        return .ok()
    }
}
