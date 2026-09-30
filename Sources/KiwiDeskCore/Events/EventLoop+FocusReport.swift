import AppKit
import ApplicationServices

/// The `kAXFocusedWindowChanged` branch (#21/#244), and the one
/// question it asks before reporting: is the app the one macOS
/// activated last (#1322).
extension EventLoop {
    /// The `kAXFocusedWindowChanged` branch, on its own so a test
    /// can drive it past the handler's process-policy guard.
    ///
    /// The id comes from the tracked map and a tracked window's
    /// report rides one off-main frame read, delivered by
    /// `deliverFocusReport` (#1088, input-and-animation.md). An
    /// untracked id still asks: the #21 classification needs
    /// the panel's id. The reconcile ahead of both is the #21
    /// destroy net and stays a main-actor list read.
    func handleFocusedWindowChanged(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        // Closing a window nearly always moves focus;
        // reconciling here catches missed destroy events.
        reconcile(pid: pid, app: app)
        guard
            let reported = windowID(
                of: element,
                pid: pid,
                arm: kAXFocusedWindowChangedNotification
            )
        else { return }
        // A shadow takes its process's focus as the process
        // DEACTIVATES, so its report says where the user left,
        // never where they went (#1785, device 2026-09-30).
        guard
            elements[pid]?[reported] != nil
                || !shadows.holds(reported, pid: pid)
        else {
            onLog(
                "focus: w\(reported.raw) is a shadow "
                    + "(pid \(pid)) — dropped"
            )
            return
        }
        let id = reported
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
        let requested = ContinuousClock.now
        axReads.requestFocus(element: element, pid: pid) {
            [weak self] frame in
            self?.deliverFocusReport(
                id,
                pid: pid,
                frame: frame,
                requested: requested
            )
        }
    }

    /// The report's delivery, after the read. Every gate is
    /// judged HERE, not at receipt — the read's flight is where
    /// a detach, a release, another app's activation or a focus
    /// KiwiDesk commanded can land (#1088, the rule file's
    /// delivery clause).
    private func deliverFocusReport(
        _ id: WindowID,
        pid: pid_t,
        frame: CGRect,
        requested: ContinuousClock.Instant
    ) {
        guard observers[pid] != nil, elements[pid]?[id] != nil
        else { return }
        // A dead element reads as `.zero` (#1084 review), and a
        // real on-screen window never has that frame.
        guard frame != .zero else {
            onLog("focus: w\(id.raw) dead at delivery, dropped")
            return
        }
        trackedFrames[id] = frame
        // A report older than the last focus KiwiDesk commanded
        // describes a state the command superseded; the
        // command's own echo follows, so this one is stale.
        if let commanded = lastCommandedFocus, requested < commanded {
            onLog(
                "focus: w\(id.raw) stale — a focus was commanded "
                    + "during its read, dropped"
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
        let waited = requested.duration(to: .now).components
        let ms =
            waited.seconds * 1000
            + waited.attoseconds / 1_000_000_000_000_000
        onLog("focus: w\(id.raw) liveness read \(ms)ms off main")
        onEvent(.windowFocused(id))
    }

    /// Whether `pid` is the app macOS activated last. Before any
    /// activation the frontmost reading stands in; with neither,
    /// the report stands — fails OPEN by design (#1322). Among
    /// sibling processes the announcement names the APP — a
    /// child's arrives under its parent's pid — so the process is
    /// LaunchServices' own flag, asked by its real pid (#1785).
    func reportsFromActiveApp(_ pid: pid_t) -> Bool {
        guard let active = activeAppReading() else { return true }
        guard names(active, appOf: pid) else { return false }
        guard !siblingProcesses(of: pid).isEmpty else { return true }
        // A record lost for the moment (accessibility.md) is no
        // reading: the report stands, as it did before #1785.
        return processIdentity.isActive(pid) ?? true
    }

    /// Whether an announced pid names `pid`'s app: itself, or a
    /// sibling process of it, which LaunchServices may announce
    /// in its place (#1785). The #292 preflight asks this too.
    func names(_ announced: pid_t, appOf pid: pid_t) -> Bool {
        announced == pid || areSiblings(announced, pid)
    }

    private func activeAppReading() -> pid_t? {
        (lastActivePid ?? frontmostPID()).flatMap {
            Self.isProcessID($0) ? $0 : nil
        }
    }

    private func describeActiveApp() -> String {
        activeAppReading().map { "pid \($0)" } ?? "unknown"
    }
}
