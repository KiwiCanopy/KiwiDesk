import ApplicationServices
import Foundation

/// The activation's own focus report (`appActivated`), split
/// from `EventLoop+Apps` for file size (§2).
extension EventLoop {
    /// The activation's focus report for a window the reconcile
    /// had to settle first, judged at delivery: a later
    /// activation or a commanded focus supersedes it (#1930).
    func reportActivationFocus(
        pid: pid_t,
        app: RunningApp,
        requested: ContinuousClock.Instant
    ) {
        guard lastActivePid == pid, observers[pid] != nil else {
            return
        }
        if let commanded = lastCommandedFocus, requested < commanded {
            onLog(
                "activation: pid \(pid) focus stale — a focus was "
                    + "commanded during the reconcile, dropped"
            )
            return
        }
        // Clicking a window of another app only activates the
        // app: if that window was already its app's focused
        // window, no kAXFocusedWindowChanged fires. Report the
        // cross-app focus change ourselves.
        if let id = focusedWindowID(pid: pid) {
            // Only managed windows: an ignored panel (issue
            // #21) or a not-yet-tracked window must not leak
            // a focus event with no state behind it. Surface
            // the ignored panel gaining focus, though, so the
            // dismiss report can be distrusted later (#244).
            if elements[pid]?[id] != nil {
                reportActivationFocus(id)
            } else {
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
        }
    }

    /// The activation channel's one report. Ungated: the app just
    /// activated, which is the gate's own source (#1322, censused
    /// in `FocusReportEmitterCensusTests`).
    func reportActivationFocus(_ id: WindowID) {
        onEvent(.windowFocused(id))
    }
}
