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

    var pid: pid_t {
        switch self {
        case .attach(let app, _): app.pid
        case .reconcile(let app): app.pid
        }
    }

    var name: String {
        switch self {
        case .attach(let app, _): app.ref.bundleID ?? app.ref.name
        case .reconcile(let app): app.ref.bundleID ?? app.ref.name
        }
    }
}

/// Which pass is open, so the epilogue below knows whether the
/// scan summary and `publishDisplays` are owed.
///
/// A pass owns its own identity end to end — the signpost name AND
/// the deferred slot its chunks are scheduled in. Handing the slot
/// in at the call site instead let two passes share one key, which
/// cancels a continuation and stalls a pass with no epilogue and
/// no readiness publication (architect review, 2026-08-12).
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

    /// The deferred slot this pass's chunks ride. Distinct per
    /// pass: sharing one would let the sweep cancel the scan's
    /// next chunk.
    var deferredKey: DeferredTasks.Key {
        switch self {
        case .scan: .bootScan
        case .sweep: .startupSweep
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
    /// Whether a pass is open. An explicit flag rather than the
    /// signpost interval's presence: `publishDisplays` and the
    /// summary line are production behavior, and gating them on a
    /// diagnostics handle means a change to signposting silently
    /// changes what boot does (architect review, 2026-08-12).
    var passOpen = false
    /// The per-app bound, raised ONLY while a queued step runs
    /// (#803). Not "while a pass is open": the run loop is live
    /// between chunks, so an AX-driven attach, an activation
    /// reconcile or a Desktop-switch `reconcileAll` lands *inside*
    /// a pass and must never be cut short — only the boot work
    /// this pass queued trades completeness for latency.
    var stepBudget: Duration?
    /// Apps a budget cut short, waiting for their completing
    /// reconcile — one queue for BOTH passes' epilogues, so the
    /// sweep's deferrals join the chain rather than replacing it.
    ///
    /// Here rather than on `BootRun` because this is where the
    /// reset already lives: `stop()` replaces this struct
    /// wholesale, and `stop()` is the only path to the
    /// `!isRunning` a later `beginScan` needs — so a boot cannot
    /// begin carrying the last one's queue. Held on the run
    /// instead, it was the one boot-scoped ledger nothing reset —
    /// and a `stop()` mid-drain then left it non-empty forever,
    /// so every later launch read "a chain is already running",
    /// scheduled none, and abandoned every deferred app for the
    /// session (architect review, 2026-08-12).
    var pendingDrain: [(pid_t, AppRef)] = []
    /// Apps a budget already cut short THIS boot. A pass skips
    /// them outright rather than paying the same blocking call
    /// again: the measured outlier cost 4004 ms at attach, then
    /// 5008 ms in the sweep, for one app that answers nothing
    /// (owner's device log, 2026-08-12).
    ///
    /// Cleared with the rest of this struct by `stop()` — the
    /// only way to reach a state where a new `beginScan` can run,
    /// so the list cannot cross a boot. Deliberately NOT cleared
    /// when the drain takes the deferrals: the boot tail drains a
    /// second before the sweep opens, so clearing there handed
    /// the sweep an empty list and it paid the outlier again.
    var unresponsiveApps: Set<pid_t> = []
    /// Apps a budget cut short, with the ref their completing
    /// reconcile needs. Taken by the epilogue of whichever pass
    /// deferred them — both passes budget, so both drain.
    var deferredApps: [pid_t: AppRef] = [:]
    /// The open pass's interval and its start.
    var interval: OSSignpostIntervalState?
    var began: ContinuousClock.Instant?
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
/// by itself. The per-app budget (`EventLoop+BootBudget`, #803)
/// is what bounds a chunk in practice, which is why the two ship
/// together rather than one after the other.
extension EventLoop {
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
        // A new boot has no history: an app that could not answer
        // last time deserves its chance again.
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
    /// Takes `reconcileAll`'s two loops per app instead of
    /// across all apps (a reconcile of one app never depends on
    /// another's attach), and carries the orphan observers that
    /// loop reaches — an app that has since exited is detached by
    /// its own reconcile. It does NOT take that pass's census
    /// gate (#1037), and must not: the gate skips an app showing
    /// nothing on screen, and the apps this sweep exists to warm
    /// are exactly those — the ones the boot prefilter (which
    /// counts windows on EVERY Desktop) called windowless, whose
    /// warm-on-reconcile is the #662 promise
    /// `StartupWarmupSkipTests` pins. Their AX cost is paid
    /// chunked and budgeted here, once, not on every switch.
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
        // A pass INHERITS the boot's skip list rather than
        // resetting it — that inheritance is the whole mechanism:
        // the scan gives up on an app, the sweep does not ask it
        // again. `beginScan` clears it, since that is where a
        // boot begins.
        bootScan.pass = pass
        bootScan.pending = steps
        bootScan.total = steps.count
        bootScan.scanned = 0
        bootScan.passOpen = true
        bootScan.began = monotonicNow()
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
        let deadline = budget.map { monotonicNow().advanced(by: $0) }
        while !bootScan.pending.isEmpty {
            let began = monotonicNow()
            let step = bootScan.pending.removeFirst()
            perform(step)
            bootScan.scanned += 1
            let held = began.duration(to: monotonicNow())
            if held >= Self.slowChunkReport {
                // The one number a field report cannot otherwise
                // supply: how long the main actor was held in one
                // go, which is what a delayed menu open measures.
                // The per-app spans log at 100 ms
                // (`BootSignpost.slowSpanMs`); this logs the app
                // that made a CHUNK long, budget aborts included.
                onLog(
                    "slow chunk: \(step.name) held "
                        + "\(held.wholeMilliseconds)ms"
                )
            }
            if let deadline, monotonicNow() >= deadline { break }
        }
        if bootScan.pending.isEmpty { closePass() }
        return BootScanProgress(
            scanned: bootScan.scanned,
            total: bootScan.total,
            finished: bootScan.pending.isEmpty
        )
    }

    /// A chunk at or above this held the main actor long enough
    /// for a click to feel late (~3 display frames is the felt
    /// threshold). Sized above `KiwiCore.bootChunkBudget`, which
    /// owns the cadence: anything reported here is an app
    /// overrunning its chunk, never the chunking itself.
    static let slowChunkReport: Duration = .milliseconds(50)

    /// Runs one queued step under the per-app budget. The budget
    /// is raised HERE rather than for the whole pass: nothing can
    /// interleave inside a step (main actor, no suspension), so
    /// this is exactly the boot work #803 may cut short, and every
    /// event-driven attach or reconcile that lands between chunks
    /// stays unbudgeted.
    private func perform(_ step: BootScanStep) {
        // An app this boot already gave up on is not asked again:
        // its cost is one blocking AX call, which no budget can
        // interrupt and every later pass would pay in full. The
        // drain completes it once, unbudgeted.
        guard !bootScan.unresponsiveApps.contains(step.pid) else {
            return
        }
        bootScan.stepBudget = Self.bootAppBudget
        defer { bootScan.stepBudget = nil }
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
        guard bootScan.passOpen else { return }
        let pass = bootScan.pass
        bootScan.passOpen = false
        if let interval = bootScan.interval {
            BootSignpost.signposter.endInterval(
                pass.signpostName,
                interval
            )
            bootScan.interval = nil
        }
        let began = bootScan.began ?? monotonicNow()
        let ms = began.duration(to: monotonicNow())
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
}
