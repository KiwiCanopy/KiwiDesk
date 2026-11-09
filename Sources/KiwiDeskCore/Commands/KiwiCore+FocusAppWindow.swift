import Foundation

/// `focus_app_window(direction)` (#3131): focus the frontmost
/// app's next or previous window wherever it lives — another
/// Space, another screen, a Desktop no screen shows. One step
/// of the ring Open or Focus's repeat press walks
/// (`cycleFocusedAppWindow`); this file builds no ring of its
/// own (`AppWindowCycleSeamTests`). Minimized windows are not
/// in the ring and are never restored (#673).
extension KiwiCore {
    func focusAppWindow(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = ModeCycleDirection(rawValue: raw)
        else { return .expected(ModeCycleDirection.self) }
        switch cycleFocusedAppWindow(
            direction: direction,
            verb: "focus_app_window"
        ) {
        case .stepped:
            return .ok()
        case .notFocused, .otherAppFocused:
            // `.otherAppFocused` cannot arise here: the focused
            // app is the one the step names.
            return .fail("no focused window")
        case .noBundleID:
            return .fail("only an app with a bundle id cycles its windows")
        case .notFrontmost:
            return .fail("only the app in front cycles its windows")
        case .outsideRing:
            return .fail("a transient panel is not one of its app's windows")
        case .loneWindow:
            return .fail("the focused app has no other window to focus")
        case .reachRefused:
            return .fail(
                "the window this step lands on is on a Desktop that "
                    + "could not be switched to"
            )
        }
    }
}
