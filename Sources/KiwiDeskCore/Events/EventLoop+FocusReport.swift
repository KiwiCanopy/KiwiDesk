import AppKit
import ApplicationServices

/// The `kAXFocusedWindowChanged` branch (#21/#244), and the one
/// question it asks before reporting: is the app the one macOS
/// activated last (#1322).
extension EventLoop {
    /// The `kAXFocusedWindowChanged` branch, on its own so a test
    /// can drive it past the handler's process-policy guard. It
    /// still ASKS for the id (`resolveWindowID`, #1088): a
    /// destroyed element answers nothing, which filters a dead
    /// window for free. Unguarded — `windowID(of:pid:)`'s privacy
    /// is the tripwire, and `deadElementIsNotReported` is not the
    /// pin.
    func handleFocusedWindowChanged(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        // Closing a window nearly always moves focus;
        // reconciling here catches missed destroy events.
        reconcile(pid: pid, app: app)
        guard let id = resolveWindowID(element) else { return }
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
        // A focus report from an app macOS did not activate is
        // app-internal; dropped, never held (#1322).
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
