import ApplicationServices
import Foundation

/// The activation's own focus report (`appActivated`), split
/// from `EventLoop+Apps` for file size (§2).
extension EventLoop {
    /// Reads the activated app's focused window off the main
    /// actor (#1930) and reports it at delivery.
    func requestActivationFocus(pid: pid_t, app: RunningApp) {
        let requested = ContinuousClock.now
        nonisolated(unsafe) let read = shadows.focusedWindow
        axReads.requestFocusedWindow(pid: pid) {
            read(pid)
        } onID: { [weak self] raw in
            self?.deliverActivationFocus(
                raw,
                pid: pid,
                app: app,
                requested: requested,
                settled: false
            )
        }
    }

    /// The activation's focus report, judged at delivery: a later
    /// activation or a commanded focus supersedes it (#1930). An
    /// untracked window waits for a reconcile first, so a window
    /// tracked late (cold Electron tree, other native Space) is
    /// known before the managed-window guard.
    private func deliverActivationFocus(
        _ raw: WindowID?,
        pid: pid_t,
        app: RunningApp,
        requested: ContinuousClock.Instant,
        settled: Bool
    ) {
        guard lastActivePid == pid, observers[pid] != nil else {
            return
        }
        if let commanded = lastCommandedFocus, requested < commanded {
            onLog(
                "activation: pid \(pid) focus stale — a focus was "
                    + "commanded during its read, dropped"
            )
            return
        }
        // Clicking a window of another app only activates the
        // app: if that window was already its app's focused
        // window, no kAXFocusedWindowChanged fires. Report the
        // cross-app focus change ourselves.
        guard let raw else { return }
        let id = hostOfShadow(raw, pid: pid)
        // Only managed windows: an ignored panel (issue #21) or a
        // not-yet-tracked window must not leak a focus event with
        // no state behind it. Surface the ignored panel gaining
        // focus, though, so the dismiss report can be distrusted
        // later (#244).
        if elements[pid]?[id] != nil {
            reportActivationFocus(id)
            return
        }
        guard settled else {
            reconcileOffMain(pid: pid, app: app.ref) { [weak self] in
                self?.deliverActivationFocus(
                    raw,
                    pid: pid,
                    app: app,
                    requested: requested,
                    settled: true
                )
            }
            return
        }
        classifyUntrackedFocus(
            id: id,
            pid: pid,
            bundleID: app.ref.bundleID,
            isAccessory: Self.classifiesAsOverlay(
                pid: pid,
                activationPolicy: app.activationPolicy
            ),
            channel: "activation"
        )
    }

    /// The activation channel's one report. Ungated: the app just
    /// activated, which is the gate's own source (#1322, censused
    /// in `FocusReportEmitterCensusTests`).
    func reportActivationFocus(_ id: WindowID) {
        onEvent(.windowFocused(id))
    }
}
