import AppKit
import ApplicationServices

extension AXHelper {
    /// Raises a window on its own native full-screen Space so macOS
    /// shows that Space (#2939): activates the app FIRST, then makes
    /// the window main and raises it — the reverse of `raise`'s #496
    /// order, since macOS switches to a full-screen Space only for a
    /// raise that lands while its app is frontmost (measured
    /// 2026-11-02 on one and two screens; the issue has the logs).
    /// False, touching nothing, where `element` no longer names
    /// `window`.
    @MainActor
    public static func activateThenRaise(
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
