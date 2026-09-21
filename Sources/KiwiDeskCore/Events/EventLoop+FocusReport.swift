import AppKit
import ApplicationServices

/// The `kAXFocusedWindowChanged` branch (#21/#244), and the one
/// question it asks before reporting: is the app the one macOS
/// activated last (#1322).
extension EventLoop {
    /// The `kAXFocusedWindowChanged` branch, on its own so a test
    /// can drive it past the handler's process-policy guard.
    ///
    /// The id comes from the tracked map (#1084/#1088); a
    /// tracked window's report then rides one off-main frame
    /// read (#618's shape) and is delivered by
    /// `deliverFocusReport`, which drops a dead element on its
    /// `.zero` frame — the liveness the ask used to give for
    /// free. An untracked id still asks: the #21 classification
    /// needs the panel's id, and the ask is the one reader that
    /// has it. The reconcile ahead of both is the #21 destroy
    /// net and stays a main-actor list read; it is not this
    /// route's subject.
    func handleFocusedWindowChanged(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        // Closing a window nearly always moves focus;
        // reconciling here catches missed destroy events.
        reconcile(pid: pid, app: app)
        guard
            let id = windowID(
                of: element,
                pid: pid,
                arm: kAXFocusedWindowChangedNotification
            )
        else { return }
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
        axReads.request(
            .focused,
            window: id,
            element: element,
            pid: pid
        ) { [weak self] frame in
            self?.deliverFocusReport(
                id,
                pid: pid,
                frame: frame,
                requested: requested
            )
        }
    }

    /// The report's delivery, one run-loop hop after the
    /// notification. Every gate is judged HERE rather than at
    /// receipt: the observer and the registration because a
    /// detach or a release can land inside the read's flight,
    /// and the #1322 provenance because two apps' reads ride
    /// two queues — a slow app's report landing after a fast
    /// app's activation is the reorder that would otherwise
    /// park the focus on the wrong app.
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
