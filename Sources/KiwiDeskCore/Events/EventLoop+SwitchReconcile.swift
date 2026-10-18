import ApplicationServices
import Foundation
import os

/// A Desktop switch's bulk re-sync, read OFF the main actor
/// (#2347): one list read per gated app, applied in ONE switch
/// fold once every read has landed or the bound has passed.
/// Between two busy Desktops the synchronous pass held the main
/// actor 90–100 ms per switch (device, 2026-10-18).
struct SwitchReconcile {
    /// One app's read for the open batch.
    struct Read {
        let app: AppRef
        let tracked: Set<WindowID>
        let writesAtRead: Int
        let started: ContinuousClock.Instant
        var reading: WindowListReading?
        var applied = false
    }

    struct Batch {
        let generation: Int
        /// The switch grace as the reads began; the sweep judges
        /// the census by it, never by the apply's clock.
        let grace: Bool
        /// The gate's order, which the apply keeps.
        var order: [pid_t] = []
        var reads: [pid_t: Read] = [:]
        /// The fold of what landed by the bound, or of every read,
        /// has run; a later read applies alone.
        var mainApplied = false
    }

    /// The bound on the batch's one fold: past it, what landed
    /// applies and a straggler applies alone. Under the switch
    /// grace (`EventLoop.spaceSwitchCoalesceGrace`) and the 600 ms
    /// settle, so neither waits on one slow app.
    static let bound: TimeInterval = 0.4
    /// A straggler read older than this is re-read instead,
    /// since the carried arm's in-flight span (`KiwiCore
    /// .inFlightWindow`) no longer covers a carried window it
    /// misses (`SwitchReconcileTests` pins the order).
    static let stragglerLimit: TimeInterval = 5

    var generation = 0
    var batch: Batch?
    /// Per app, when the read behind its newest applied reconcile
    /// began; a batch read begun before it answers nothing.
    private(set) var appliedRead: [pid_t: ContinuousClock.Instant] = [:]
    /// The Desktop settle owed once the batch's fold has run: one
    /// slot, latest wins (#49), emptied by the next switch.
    var parkedSettle: (@MainActor () -> Void)?
    /// A bar refresh asked while the batch was pending.
    var barsOwed = false
    typealias Work = @MainActor @Sendable () -> Void
    /// Runs `work` after `delay` on the main actor; injected in
    /// tests.
    var scheduleBound: @MainActor (TimeInterval, @escaping Work) -> Void = {
        delay,
        work in
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: work
        )
    }
    /// The batch's fold has run: the core pays the bars it held.
    var onApplied: @MainActor () -> Void = {}

    /// A switch's fold has not run yet: its arrivals and
    /// departures are still unapplied.
    var isPending: Bool { batch.map { !$0.mainApplied } ?? false }

    /// An app whose switch read has not applied.
    func isOutstanding(_ pid: pid_t) -> Bool {
        batch?.reads[pid].map { !$0.applied } ?? false
    }

    mutating func noteApplied(
        _ pid: pid_t,
        readAt: ContinuousClock.Instant
    ) {
        if let last = appliedRead[pid], last >= readAt { return }
        appliedRead[pid] = readAt
    }

    func answeredSince(_ pid: pid_t, _ read: Read) -> Bool {
        appliedRead[pid].map { $0 > read.started } ?? false
    }

    /// Forgets the batch and what waits on it, at a stop; the
    /// generation stays, so a read from before answers nothing.
    mutating func drop() {
        batch = nil
        parkedSettle = nil
        barsOwed = false
        appliedRead = [:]
    }
}

extension EventLoop {
    /// Opens the switch's batch ahead of the handler, so the
    /// handler's own bar refresh waits for the arrivals
    /// (`holdsBarsForSwitch`), and drops a superseded batch.
    func beginSwitchReconcile() {
        switchReads.generation += 1
        switchReads.parkedSettle = nil
        switchReads.batch = SwitchReconcile.Batch(
            generation: switchReads.generation,
            grace: isWithinSpaceSwitchGrace()
        )
    }

    /// Requests the batch's reads, after the handler: its bound
    /// profile's rules decide what the gate observes (#2405).
    func requestSwitchReads() {
        let signposter = BootSignpost.signposter
        let span = signposter.beginInterval("switchReconcile")
        defer { signposter.endInterval("switchReconcile", span) }
        WorkMeter.shared.add(\.bulkReconciles)
        guard var batch = switchReads.batch else { return }
        let generation = batch.generation
        let targets = bulkTargets()
        batch.order = targets
        for pid in targets {
            let app = appRef(of: pid)
            let tracked = Set(elements[pid]?.keys ?? [:].keys)
            batch.reads[pid] = SwitchReconcile.Read(
                app: app,
                tracked: tracked,
                writesAtRead: offMain.writes,
                started: .now
            )
        }
        switchReads.batch = batch
        guard !targets.isEmpty else {
            return applySwitchReads(targets, generation: generation)
        }
        for pid in targets {
            guard let read = batch.reads[pid] else { continue }
            axReads.requestSwitchList(
                pid: pid,
                read: windowListRead(
                    pid: pid,
                    app: read.app,
                    tracked: read.tracked,
                    listsWhenHidden: false
                )
            ) { [weak self] reading in
                self?.deliverSwitchRead(
                    reading,
                    pid: pid,
                    generation: generation
                )
            }
        }
        switchReads.scheduleBound(SwitchReconcile.bound) {
            [weak self] in
            self?.cutSwitchBatch(generation: generation)
        }
    }

    /// Runs the Desktop settle now, or after the pending batch's
    /// fold — one slot, so the latest settle wins (#49).
    func settleAfterSwitchReads(_ work: @escaping @MainActor () -> Void) {
        guard switchReads.isPending else { return work() }
        switchReads.parkedSettle = work
    }

    private func deliverSwitchRead(
        _ reading: WindowListReading,
        pid: pid_t,
        generation: Int
    ) {
        guard switchReads.batch?.generation == generation,
            switchReads.batch?.reads[pid] != nil
        else { return }
        switchReads.batch?.reads[pid]?.reading = reading
        guard let batch = switchReads.batch else { return }
        if batch.mainApplied {
            applySwitchReads([pid], generation: generation)
        } else if !batch.reads.values.contains(where: {
            $0.reading == nil
        }) {
            applySwitchReads(batch.order, generation: generation)
        }
    }

    /// The bound passed: what landed applies in the one fold.
    private func cutSwitchBatch(generation: Int) {
        guard let batch = switchReads.batch,
            batch.generation == generation, !batch.mainApplied
        else { return }
        let slow = batch.order.filter { batch.reads[$0]?.reading == nil }
        onLog(
            "switch reconcile: \(slow.count) app(s) past "
                + "\(Int(SwitchReconcile.bound * 1000))ms — "
                + "applying without them"
        )
        applySwitchReads(batch.order, generation: generation)
    }

    /// Applies the landed, unapplied reads of `pids` in one fold;
    /// the first apply is the batch's fold, after which the held
    /// bars and the parked settle are paid.
    private func applySwitchReads(_ pids: [pid_t], generation: Int) {
        guard var batch = switchReads.batch,
            batch.generation == generation
        else { return }
        let landed = pids.filter {
            batch.reads[$0].map { $0.reading != nil && !$0.applied }
                ?? false
        }
        for pid in landed { batch.reads[pid]?.applied = true }
        let paysFold = !batch.mainApplied
        batch.mainApplied = true
        let grace = batch.grace
        let reads = landed.compactMap { pid in
            batch.reads[pid].map { (pid, $0) }
        }
        switchReads.batch =
            batch.reads.values.allSatisfy(\.applied) ? nil : batch
        foldsSwitchResync {
            for (pid, read) in reads {
                applySwitchRead(read, pid: pid, grace: grace)
            }
        }
        guard paysFold else { return }
        switchReads.onApplied()
        if let settle = switchReads.parkedSettle {
            switchReads.parkedSettle = nil
            settle()
        }
    }

    /// One app's reading, unless a newer reading already answered
    /// for it — an app's readings apply in read order — or it is
    /// older than the carried arm covers.
    private func applySwitchRead(
        _ read: SwitchReconcile.Read,
        pid: pid_t,
        grace: Bool
    ) {
        guard let reading = read.reading,
            !switchReads.answeredSince(pid, read)
        else { return }
        let age = read.started.duration(to: .now)
        guard age < .seconds(SwitchReconcile.stragglerLimit) else {
            return reconcileOffMain(
                pid: pid,
                app: read.app,
                coalesceTabs: false
            )
        }
        let answered = reconcile(
            pid: pid,
            app: read.app,
            coalesceTabs: false,
            prefetched: PrefetchedWindows(
                elements: reading.elements,
                trackedAtRead: read.tracked,
                windows: reading.windows,
                layers: reading.layers,
                writesAtRead: read.writesAtRead,
                policy: reading.policy,
                hidden: reading.hidden,
                listRead: reading.listRead,
                readStarted: read.started,
                switchGrace: grace
            )
        )
        // A skipped list met an unhide: a fresh read answers.
        if !answered {
            reconcileOffMain(pid: pid, app: read.app, coalesceTabs: false)
        }
    }
}
