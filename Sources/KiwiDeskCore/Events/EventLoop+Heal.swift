import AppKit
import ApplicationServices

/// The adoption heal (#675): a WindowServer-count-gated sweep
/// that re-adopts windows every event path missed. The event
/// paths can all go silent at once for a fresh-launch app — the
/// observer's registration can fail without a word, and then no
/// notification, no activation and no space change ever comes
/// for it — so a timed backstop is the only pass *guaranteed*
/// to run. It stays cheap by design: one census snapshot
/// (~1 ms, no AX) per tick, and an AX reconcile only where the
/// census says a window is missing.
extension EventLoop {
    /// One census, one pass over the running apps. Fires a
    /// reconcile only where the WindowServer sees more normal
    /// windows than are tracked (or an app with windows has no
    /// observer at all — a launch-time attach that failed), and
    /// repairs any observer whose app-level registration failed.
    /// A pass that adopts nothing goes quiet for that census
    /// value (`healQuiet`), so a permanent mismatch — an ignored
    /// layer-0 panel — stops costing reconciles until the count
    /// moves again.
    ///
    /// What this deliberately cannot heal: a window on another
    /// native desktop. AX and the on-screen census both exclude
    /// it, so it is adopted when its desktop is visited (the
    /// native-space-change `reconcileAll`) —
    /// `docs/accepted-limitations.md` carries the row.
    func healSweep() {
        guard isRunning else { return }
        let counts = onScreenNormalWindowCounts()
        var quiet: [pid_t: Int] = [:]
        for app in runningApplications() {
            let pid = app.pid
            let ws = counts[pid] ?? 0
            if let observer = observers[pid] {
                if observer.needsRegistrationRepair {
                    observer.repairRegistration()
                }
                let tracked = elements[pid]?.count ?? 0
                guard ws > tracked else { continue }
                if healQuiet[pid] == ws {
                    quiet[pid] = ws
                    continue
                }
                reconcile(pid: pid, app: app.ref)
                let after = elements[pid]?.count ?? 0
                if after > tracked {
                    logHeal(app: app.ref, adopted: after - tracked)
                } else {
                    quiet[pid] = ws
                }
            } else if ws > 0 {
                if healQuiet[pid] == ws {
                    quiet[pid] = ws
                    continue
                }
                // The launch-time attach failed or never ran
                // (`AXObserverCreate` can refuse a not-yet-ready
                // app). The reconcile takes this app's window
                // snapshot on the same turn — no second scan at
                // attach (#672).
                syncObservation(
                    for: app,
                    scanWindowsAtAttach: false
                )
                guard observers[pid] != nil else {
                    // Ignored or prohibited: hush until the
                    // census moves.
                    quiet[pid] = ws
                    continue
                }
                reconcile(pid: pid, app: app.ref)
                let after = elements[pid]?.count ?? 0
                if after > 0 {
                    logHeal(app: app.ref, adopted: after)
                } else {
                    quiet[pid] = ws
                }
            }
        }
        // Wholesale replace: entries for exited apps and healed
        // counts fall away, so the ledger stays bounded by the
        // live mismatches.
        healQuiet = quiet
    }

    /// A heal that adopted something is field evidence for #675's
    /// intermittent repro — leave a line on record, like the boot
    /// scan does.
    private func logHeal(app: AppRef, adopted: Int) {
        let name = app.bundleID ?? app.name
        onLog("adoption heal: \(name) +\(adopted) window(s)")
    }
}
