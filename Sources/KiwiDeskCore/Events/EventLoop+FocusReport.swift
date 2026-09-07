import AppKit
import ApplicationServices

/// The `kAXFocusedWindowChanged` branch (#21/#244), and the one
/// question it asks before reporting: is the app the one macOS
/// activated last (#1322). Split from `EventLoop+Notifications`
/// at the §2.1 ceiling.
extension EventLoop {
    /// The `kAXFocusedWindowChanged` branch, on its own so a test
    /// can drive it past the handler's process-policy guard.
    func handleFocusedWindowChanged(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        // Closing a window nearly always moves focus;
        // reconciling here catches missed destroy events.
        reconcile(pid: pid, app: app)
        guard let id = windowID(of: element, pid: pid) else {
            return
        }
        // Focus events carry only managed windows: the
        // reconcile above just settled tracking, so an
        // absent id is an ignored panel (issue #21) —
        // reporting it would emit a focus_change with an
        // empty app and retile focus-driven layouts. Surface
        // the panel gaining focus so KiwiCore can distrust
        // the app's stale focus report on dismiss (#244).
        guard elements[pid]?[id] != nil else {
            classifyUntrackedFocus(
                id: id,
                pid: pid,
                bundleID: app.bundleID,
                isAccessory: classifiesAsOverlay(pid: pid),
                channel: "focus"
            )
            return
        }
        // An app-INTERNAL focus change: a non-activating panel
        // opening or closing makes its app re-announce its main
        // window while another app keeps the system focus (#1322).
        // Dropped, not held — if the app does activate, the
        // activation channel reports its focused window itself.
        guard reportsFromActiveApp(pid) else {
            onLog(
                "focus: w\(id.raw) app-internal (pid \(pid), "
                    + "active app \(describeActiveApp())) dropped"
            )
            return
        }
        onEvent(.windowFocused(id))
    }

    /// Whether `pid` is the app macOS activated last. Before any
    /// activation the frontmost reading stands in; with neither,
    /// the report stands — fails OPEN by design (#1322).
    func reportsFromActiveApp(_ pid: pid_t) -> Bool {
        guard let active = lastActivePid ?? frontmostPID() else {
            return true
        }
        return active == pid
    }

    private func describeActiveApp() -> String {
        (lastActivePid ?? frontmostPID()).map { "pid \($0)" }
            ?? "unknown"
    }
}
