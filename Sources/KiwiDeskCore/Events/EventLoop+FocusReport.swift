import AppKit
import ApplicationServices

/// Which focus report may still land (#1930): every report asked
/// for takes a ticket from one counter that never resets, and a
/// report delivered late stands only while its app has EMITTED
/// none newer — a newer one that was dropped (a dead element, a
/// shadow, a panel) supersedes nothing.
struct FocusReportOrder {
    private var issued = 0
    private var emitted: [pid_t: Int] = [:]

    mutating func issueTicket() -> Int {
        issued += 1
        return issued
    }

    mutating func noteEmitted(_ ticket: Int, pid: pid_t) {
        emitted[pid] = max(emitted[pid] ?? 0, ticket)
    }

    func isSuperseded(_ ticket: Int, pid: pid_t) -> Bool {
        (emitted[pid] ?? 0) > ticket
    }
}

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
    /// the panel's id. The reconcile beside both is the #21
    /// destroy net, its list read off the main actor (#1930): a
    /// tracked id reports at once, any other after the reconcile
    /// settled tracking — and only while the app emitted no newer
    /// report (`FocusReportOrder`).
    func handleFocusedWindowChanged(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        let requested = ContinuousClock.now
        let ticket = focusOrder.issueTicket()
        let reported = windowID(
            of: element,
            pid: pid,
            arm: kAXFocusedWindowChangedNotification
        )
        // Closing a window nearly always moves focus;
        // reconciling here catches missed destroy events.
        if let reported, elements[pid]?[reported] != nil {
            requestFocusReport(
                reported,
                element: element,
                pid: pid,
                requested: requested,
                ticket: ticket
            )
            reconcileOffMain(pid: pid, app: app)
            return
        }
        reconcileOffMain(pid: pid, app: app) { [weak self] in
            guard let self, let reported, observers[pid] != nil,
                !focusOrder.isSuperseded(ticket, pid: pid)
            else { return }
            // A focus KiwiDesk commanded during the reconcile
            // supersedes this report, as at delivery below.
            guard !focusCommanded(since: requested) else {
                onLog(
                    "focus: w\(reported.raw) stale — a focus was "
                        + "commanded during its reconcile, dropped"
                )
                return
            }
            settleFocusReport(
                reported,
                element: element,
                pid: pid,
                app: app,
                requested: requested,
                ticket: ticket
            )
        }
    }

    /// The report of a window that was untracked when it came
    /// in, after the reconcile settled tracking (#1930).
    private func settleFocusReport(
        _ reported: WindowID,
        element: AXUIElement,
        pid: pid_t,
        app: AppRef,
        requested: ContinuousClock.Instant,
        ticket: Int
    ) {
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
        requestFocusReport(
            id,
            element: element,
            pid: pid,
            requested: requested,
            ticket: ticket
        )
    }

    /// One off-main liveness read behind a tracked window's
    /// report, delivered by `deliverFocusReport` (#1088).
    private func requestFocusReport(
        _ id: WindowID,
        element: AXUIElement,
        pid: pid_t,
        requested: ContinuousClock.Instant,
        ticket: Int
    ) {
        axReads.requestFocus(element: element, pid: pid) {
            [weak self] frame in
            self?.deliverFocusReport(
                id,
                pid: pid,
                frame: frame,
                requested: requested,
                ticket: ticket
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
        requested: ContinuousClock.Instant,
        ticket: Int
    ) {
        guard observers[pid] != nil, elements[pid]?[id] != nil
        else { return }
        // The app emitted a newer report meanwhile (#1930).
        guard !focusOrder.isSuperseded(ticket, pid: pid) else {
            onLog("focus: w\(id.raw) superseded by a newer report")
            return
        }
        // A dead element reads as `.zero` (#1084 review), and a
        // real on-screen window never has that frame.
        guard frame != .zero else {
            onLog("focus: w\(id.raw) dead at delivery, dropped")
            return
        }
        trackedFrames[id] = frame
        offMain.noteFreshWrite(id, [.frame])
        // A report older than the last focus KiwiDesk commanded
        // describes a state the command superseded; the
        // command's own echo follows, so this one is stale.
        guard !focusCommanded(since: requested) else {
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
        focusOrder.noteEmitted(ticket, pid: pid)
        onEvent(.windowFocused(id))
    }

    /// Whether KiwiDesk commanded a focus after `requested`: a
    /// report asked before it describes a state the command
    /// superseded, and the command's own echo follows (#1088).
    func focusCommanded(since requested: ContinuousClock.Instant)
        -> Bool
    {
        guard let commanded = lastCommandedFocus else { return false }
        return requested < commanded
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
