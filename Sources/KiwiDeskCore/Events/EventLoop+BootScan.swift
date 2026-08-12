import AppKit
import ApplicationServices
import os

/// One app's share of a chunked pass. Attach for the startup
/// scan, reconcile for the startup sweep — the two passes differ
/// only in the step they queue and in what their driver does when
/// the queue empties.
enum BootScanStep {
    case attach(RunningApp, scanWindows: Bool)
    case reconcile(RunningApp)
}

/// Which pass is open, so the epilogue below knows whether the
/// scan summary and `publishDisplays` are owed.
enum BootScanPass {
    case scan
    case sweep

    /// The `os_signpost` interval name — one derivation, since
    /// opening and closing an interval under different names
    /// leaves an unclosed span in Instruments.
    var signpostName: StaticString {
        switch self {
        case .scan: "startupScan"
        case .sweep: "startupSweep"
        }
    }
}

/// What the caller needs to decide whether to schedule another
/// chunk, and what the readiness signal reads (#802).
struct BootScanProgress {
    let scanned: Int
    let total: Int
    let finished: Bool
}

/// The chunked pass's own state. A holder rather than eight more
/// stored properties on `EventLoop`, which is already at the
/// §2.1 sweet spot.
struct BootScanState {
    /// Apps this pass has not visited yet.
    var pending: [BootScanStep] = []
    /// Apps visited, and apps the pass started with. `scanned`
    /// counts every app *looked at*, including the ones that
    /// attach to nothing — `BootPhase` carries why the honest
    /// count is that one and not the attach tally.
    var scanned = 0
    var total = 0
    var pass: BootScanPass = .scan
    /// The per-app bound while this pass runs (#803); nil outside
    /// one, which is what keeps every event-driven attach and
    /// reconcile unbudgeted.
    var appBudget: Duration?
    /// Apps a budget cut short, with the ref their completing
    /// reconcile needs. Drained after boot, unbudgeted.
    var deferredApps: [pid_t: AppRef] = [:]
    /// The open `startupScan` interval and its start.
    var interval: OSSignpostIntervalState?
    var began: ContinuousClock.Instant?
    /// The budgets' only time source. A seam because a budget is
    /// otherwise unobservable from a test — every injected AX
    /// fake answers instantly, so nothing can spend wall-clock
    /// and `Task.sleep` in a guard is what tests.md forbids.
    var now: () -> ContinuousClock.Instant = { .now }
}

/// The chunked boot pass (#801).
///
/// The scan used to run as one synchronous block: on a heavy
/// session (109 running apps) that is ~10 s during which the
/// menu-bar item and ⌃⌥K are dead, because boot holds the very
/// run loop the menu needs — and it ended with every window on
/// the desk retiling at once, unannounced. So the work is a queue
/// now, and the driver (`KiwiCore+Boot`) hands the run loop back
/// between chunks.
///
/// Chunking alone does not buy responsiveness: one app's blocking
/// AX work is indivisible, and the measured outlier cost 5011 ms
/// by itself. The per-app budget below is what bounds a chunk in
/// practice, which is why #803 rides with #801 rather than after
/// it.
extension EventLoop {
    /// Per-app wall-clock bound for a chunked pass (#803).
    ///
    /// 500 ms sits clear of the healthy band — Electron/WebKit
    /// answer lazily at 100–300 ms (accessibility.md) — and
    /// inside one AX messaging timeout
    /// (`axMessagingTimeoutSeconds`), so an app that spent a
    /// whole timeout on its first call is deferred instead of
    /// paying that price again for every window it lists.
    static let bootAppBudget: Duration = .milliseconds(500)

    /// Opens the chunked startup scan. Returns false when the
    /// loop is already running — a second start is inert (#672),
    /// and the caller must not then drive chunks.
    func beginScan() -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        // Bound every AX message before the first per-app call:
        // an unresponsive app otherwise costs the ~6 s system
        // default per call (#672).
        applyAXMessagingTimeout(Self.axMessagingTimeoutSeconds)
        if registersWorkspaceObservers {
            registerWorkspaceObservers()
        }
        let visible = visiblePIDs()
        let apps = runningApplications()
        open(
            .scan,
            steps: apps.map {
                .attach($0, scanWindows: visible.contains($0.pid))
            }
        )
        return true
    }

    /// Opens the chunked startup sweep — the same queue, carrying
    /// reconciles. Chunked and budgeted for the same reason the
    /// scan is: the sweep runs one second after boot and measured
    /// 5285 ms of it in one blocking block, so an unchunked sweep
    /// re-breaks the menu right after the scan freed it.
    ///
    /// Mirrors `reconcileAll`'s two loops per app instead of
    /// across all apps (a reconcile of one app never depends on
    /// another's attach), and carries the orphan observers that
    /// loop reaches — an app that has since exited is detached by
    /// its own reconcile.
    func beginSweep() -> Bool {
        guard isRunning else { return false }
        let apps = runningApplications()
        var steps: [BootScanStep] = apps.map { .reconcile($0) }
        let live = Set(apps.map(\.pid))
        for pid in observers.keys where !live.contains(pid) {
            steps.append(
                .reconcile(
                    RunningApp(
                        pid: pid,
                        activationPolicy: activationPolicy(pid)
                            ?? .prohibited,
                        ref: AppRef(pid: pid)
                    )
                )
            )
        }
        open(.sweep, steps: steps)
        return true
    }

    private func open(_ pass: BootScanPass, steps: [BootScanStep]) {
        bootScan.pass = pass
        bootScan.pending = steps
        bootScan.total = steps.count
        bootScan.scanned = 0
        bootScan.appBudget = Self.bootAppBudget
        bootScan.began = bootScan.now()
        bootScan.interval = BootSignpost.signposter
            .beginInterval(pass.signpostName)
    }

    /// Runs queued work until `budget` is spent, then returns so
    /// the driver can hand the run loop back. A nil budget drains
    /// the whole queue in one call.
    ///
    /// The budget is checked *after* an app, never before: one
    /// app's AX work is indivisible, so a chunk overruns by
    /// whatever that app costs — bounded by `bootAppBudget`,
    /// which is the whole reason the two ship together.
    @discardableResult
    func scanChunk(budget: Duration?) -> BootScanProgress {
        let deadline = budget.map { bootScan.now().advanced(by: $0) }
        while !bootScan.pending.isEmpty {
            perform(bootScan.pending.removeFirst())
            bootScan.scanned += 1
            if let deadline, bootScan.now() >= deadline { break }
        }
        if bootScan.pending.isEmpty { closePass() }
        return BootScanProgress(
            scanned: bootScan.scanned,
            total: bootScan.total,
            finished: bootScan.pending.isEmpty
        )
    }

    private func perform(_ step: BootScanStep) {
        switch step {
        case .attach(let app, let scanWindows):
            attach(
                pid: app.pid,
                activationPolicy: app.activationPolicy,
                ref: app.ref,
                scanWindowsAtAttach: scanWindows
            )
        case .reconcile(let app):
            // Rules can detach an already-observed app or make a
            // formerly ignored one observable; the reconcile
            // below takes the window snapshot, so the attach
            // skips its own (#672 scan dedup).
            syncObservation(for: app, scanWindowsAtAttach: false)
            guard observers[app.pid] != nil else { return }
            // Never coalesce native tabs in a bulk pass: same-app
            // windows across Desktops tile to identical frames
            // and would false-merge into a re-key (#308).
            reconcile(
                pid: app.pid,
                app: app.ref,
                coalesceTabs: false
            )
        }
    }

    /// Ends the pass's interval and pays its epilogue. Idempotent
    /// on the interval, so a `scanChunk` called after the queue
    /// emptied neither double-ends the signpost nor logs twice.
    private func closePass() {
        guard let interval = bootScan.interval else { return }
        let pass = bootScan.pass
        BootSignpost.signposter.endInterval(
            pass.signpostName,
            interval
        )
        bootScan.interval = nil
        bootScan.appBudget = nil
        let began = bootScan.began ?? bootScan.now()
        let ms = began.duration(to: bootScan.now())
            .wholeMilliseconds
        switch pass {
        case .scan:
            onLog(
                "startup scan: \(observers.count) apps attached "
                    + "of \(bootScan.total) running in \(ms)ms"
            )
            publishDisplays()
        case .sweep:
            onLog("startup sweep: \(ms)ms")
        }
    }

    // MARK: - The per-app budget (#803)

    /// A checkpoint an app's boot work consults between blocking
    /// AX calls. Outside a chunked pass every call answers
    /// `false`, so an event-driven attach or reconcile is never
    /// cut short — only boot trades completeness for latency.
    struct AppBudget {
        let deadline: ContinuousClock.Instant?
        let now: () -> ContinuousClock.Instant

        var isSpent: Bool {
            guard let deadline else { return false }
            return now() >= deadline
        }
    }

    /// The budget for one app, opened at the start of its work.
    func openAppBudget() -> AppBudget {
        AppBudget(
            deadline: bootScan.appBudget.map {
                bootScan.now().advanced(by: $0)
            },
            now: bootScan.now
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

    /// The deferred apps, and the pass's ledger cleared — the
    /// driver takes them exactly once.
    func takeDeferredBootApps() -> [pid_t: AppRef] {
        let apps = bootScan.deferredApps
        bootScan.deferredApps = [:]
        return apps
    }
}
