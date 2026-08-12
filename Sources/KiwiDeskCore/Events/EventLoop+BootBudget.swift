import AppKit
import ApplicationServices

/// The per-app boot budget (#803) — split from
/// `EventLoop+BootScan.swift` for file size (§2.1); the pass that
/// raises it lives there.
///
/// One app's AX work cannot be divided, so chunking alone leaves
/// the main actor held for as long as the slowest app takes: on
/// the measured session one app's reconcile was 5011 ms of the
/// sweep's 5285 ms. Past its budget an app's remaining boot work
/// is dropped, its name logged, and the app completed after the
/// pass — deferral with completion, never abandonment.
extension EventLoop {
    /// Per-app wall-clock bound for a queued boot step.
    ///
    /// 500 ms sits clear of the healthy band — Electron/WebKit
    /// answer lazily at 100–300 ms (accessibility.md) — and
    /// inside one AX messaging timeout
    /// (`axMessagingTimeoutSeconds`), so an app that spent a
    /// whole timeout on its first call is deferred instead of
    /// paying that price again for every window it lists.
    static let bootAppBudget: Duration = .milliseconds(500)

    /// A checkpoint an app's boot work consults between blocking
    /// AX calls. Outside a queued boot step every call answers
    /// `false`, so an attach or reconcile the OS drove — an app
    /// launching, an activation, a Desktop switch — is never cut
    /// short, even when it lands between two chunks of an open
    /// pass. Only the work a pass queued trades completeness for
    /// latency.
    struct AppBudget {
        let openedAt: ContinuousClock.Instant
        let deadline: ContinuousClock.Instant?
        let now: () -> ContinuousClock.Instant

        var isSpent: Bool {
            guard let deadline else { return false }
            return now() >= deadline
        }

        /// Milliseconds spent since the budget opened, read from
        /// the SAME clock the deadline is measured on — so the
        /// number a deferral logs is the number the abort acted on
        /// (architect review, 2026-08-12).
        var spentMs: Int64 {
            openedAt.duration(to: now()).wholeMilliseconds
        }
    }

    /// The budget for one app, opened at the start of its work.
    func openAppBudget() -> AppBudget {
        let opened = monotonicNow()
        return AppBudget(
            openedAt: opened,
            deadline: bootScan.stepBudget.map {
                opened.advanced(by: $0)
            },
            now: monotonicNow
        )
    }

    /// Records an app whose remaining boot work was dropped. The
    /// pass keeps going for everyone else; the driver reconciles
    /// these unbudgeted once boot is over, on the
    /// warm-on-reconcile precedent (#662/#672) — deferral with
    /// completion rather than abandonment, which #675's heal
    /// backstop exists to make unnecessary.
    func deferBootWork(pid: pid_t, ref: AppRef, spentMs: Int64) {
        bootScan.deferredApps[pid] = ref
        onLog(
            "boot budget: \(ref.bundleID ?? ref.name) deferred "
                + "after \(spentMs)ms"
        )
    }

    /// The deferred apps, and the ledger cleared — taken by the
    /// epilogue of whichever pass deferred them. BOTH passes
    /// budget, so both drain: a sweep-deferred app taken only by
    /// the boot tail (which has already run) would sit here until
    /// `stop()` threw it away, abandoned to #675's heal — the
    /// outcome deferral exists to spare it (code review,
    /// 2026-08-12).
    func takeDeferredBootApps() -> [pid_t: AppRef] {
        let apps = bootScan.deferredApps
        bootScan.deferredApps = [:]
        return apps
    }
}
