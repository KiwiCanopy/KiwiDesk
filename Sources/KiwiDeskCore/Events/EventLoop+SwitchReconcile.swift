import ApplicationServices
import Foundation
import os

extension EventLoop {
    var switchReads: SwitchReconcile {
        get { offMain.switchBatch }
        set { offMain.switchBatch = newValue }
    }

    /// Opens the switch's batch ahead of the handler, so the
    /// handler's own bar refresh waits for the arrivals (the hold
    /// in `KiwiCore.updateBars`), and drops a superseded batch.
    func beginSwitchReconcile() {
        switchReads.generation += 1
        switchReads.parkedSettle = nil
        switchReads.batch = SwitchReconcile.Batch(
            generation: switchReads.generation
        )
    }

    /// Requests the batch's reads, after the handler: its bound
    /// profile's rules decide what the gate observes (#2405). The
    /// AX messages are the inline pass's, per gated app, asked off
    /// the main actor.
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

    /// Runs `work` now, or after the pending batch's fold, in the
    /// order it was owed.
    func afterSwitchReads(_ work: @escaping @MainActor () -> Void) {
        guard switchReads.isPending else { return work() }
        switchReads.afterFold.append(work)
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
        var applies: [SwitchReconcile.Held] = landed.compactMap { pid in
            batch.reads[pid].map { read in
                SwitchReconcile.Held(
                    start: read.reading?.readStarted ?? read.started
                ) { [self] in applySwitchRead(read, pid: pid) }
            }
        }
        if paysFold {
            applies += switchReads.held
            switchReads.held = []
        }
        switchReads.batch =
            batch.reads.values.allSatisfy(\.applied) ? nil : batch
        foldsSwitchResync {
            // The batch's own fold reveals; a straggler's lone apply
            // is an ordinary late read.
            switchReads.applying = paysFold
            defer { switchReads.applying = false }
            // Newest first: an older reading of an app the newest
            // answered applies nothing, or it would sweep a window
            // the newer one lists and re-create it.
            for apply in applies.sorted(by: { $0.start > $1.start }) {
                apply.apply()
            }
        }
        guard paysFold else { return }
        switchReads.onApplied()
        let owed = switchReads.afterFold
        switchReads.afterFold = []
        for work in owed { work() }
        if let settle = switchReads.parkedSettle {
            switchReads.parkedSettle = nil
            settle()
        }
    }

    /// One app's reading, unless a newer reading already answered
    /// for it — an app's readings apply in read order — or it is
    /// older than the carried arm covers.
    private func applySwitchRead(_ read: SwitchReconcile.Read, pid: pid_t) {
        guard let reading = read.reading else { return }
        let start = reading.readStarted ?? read.started
        guard !switchReads.answeredSince(pid, start) else { return }
        guard
            read.started.duration(to: .now)
                < .seconds(SwitchReconcile.stragglerLimit)
        else {
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
                readStarted: start
            )
        )
        // A skipped list met an unhide: a fresh read answers.
        if !answered {
            reconcileOffMain(pid: pid, app: read.app, coalesceTabs: false)
        }
    }
}
