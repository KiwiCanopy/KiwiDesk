import ApplicationServices
import Foundation

/// The activation's own focus report (`appActivated`), split
/// from `EventLoop+Apps` for file size (§2).
extension EventLoop {
    /// Reads the activated app's focused window off the main
    /// actor (#1930) and reports it at delivery.
    func requestActivationFocus(pid: pid_t, app: RunningApp) {
        let requested = ContinuousClock.now
        let stamp = offMain.stampFocusReport(pid: pid)
        requestFocusedWindowID(pid: pid) { [weak self] id in
            self?.deliverActivationFocus(
                id,
                pid: pid,
                app: app,
                requested: requested,
                stamp: stamp
            )
        }
    }

    /// The activation's focus report, judged at delivery (#1930):
    /// a later activation, a newer report from the app or a
    /// commanded focus supersedes it. An untracked window waits
    /// for the reconcile the activation asked, so a window tracked
    /// late (cold Electron tree, other native Space) is known
    /// before the managed-window guard.
    private func deliverActivationFocus(
        _ id: WindowID?,
        pid: pid_t,
        app: RunningApp,
        requested: ContinuousClock.Instant,
        stamp: Int,
        settled: Bool = false
    ) {
        guard lastActivePid == pid, observers[pid] != nil,
            offMain.isNewestFocusReport(stamp, pid: pid)
        else { return }
        guard !focusCommanded(since: requested) else {
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
        guard let id else { return }
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
            afterPendingReconcile(pid: pid) { [weak self] in
                self?.deliverActivationFocus(
                    id,
                    pid: pid,
                    app: app,
                    requested: requested,
                    stamp: stamp,
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
