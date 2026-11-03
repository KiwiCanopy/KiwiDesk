import AppKit
import ApplicationServices

extension AXHelper {
    /// Raises a window on its own native full-screen Space (#2939):
    /// activates the app FIRST, then makes the window main and
    /// raises it — the reverse of `raise`'s #496 order, which did not
    /// reach the window with the app's main window on another screen.
    /// False, touching nothing, where `element` no longer names
    /// `window`.
    @MainActor
    static func activateThenRaise(
        _ element: AXUIElement,
        window: WindowID,
        pid: pid_t
    ) -> Bool {
        guard windowID(of: element) == window else { return false }
        NSRunningApplication(processIdentifier: pid)?
            .activate(options: .activateIgnoringOtherApps)
        WorkMeter.shared.ax {
            AXUIElementSetAttributeValue(
                element,
                kAXMainAttribute as CFString,
                kCFBooleanTrue
            )
        }
        WorkMeter.shared.ax {
            AXUIElementPerformAction(
                element,
                kAXRaiseAction as CFString
            )
        }
        return true
    }
}
