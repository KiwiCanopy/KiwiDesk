import Foundation

/// Tracked-state reads of an app's windows, for the callers that
/// must not ask the machine: a lens's auto-open (#3122) and
/// `open_in_background` (#3141).
extension KiwiCore {
    /// Whether `app` (a list key) has a window: one KiwiDesk tracks
    /// (the pocket's included, in either phase), one minimized, or
    /// one on another Desktop. A tracked-state read, never a census;
    /// a ⌘H-hidden app's windows are in none of the three.
    func hasTrackedWindow(app: String) -> Bool {
        func key(_ bundleID: String?, _ name: String) -> String {
            AppRef(bundleID: bundleID, name: name).listKey
        }
        return state.windows.all.contains { $0.appRef.listKey == app }
            || state.minimizeOrder.contains { key($0.bundleID, $0.app) == app }
            || state.awayWindows.values.contains {
                key($0.appBundleID, $0.appName) == app
            }
    }
}
