import AppKit
import Foundation

/// Coming up: the machine wiring `start()` arms, the chunked scan
/// that hands the run loop back between apps (#801), the
/// readiness phase a surface narrates (#802), and the tail that
/// runs once the desk is known.
///
/// Boot used to be one synchronous call. On a heavy session — 109
/// running apps measured — that call held the main actor for
/// ~10 s, which is the run loop the menu-bar item and ⌃⌥K need, so
/// an app that was visibly present answered nothing; then every
/// window on the desk retiled at once with no warning. The split
/// below is what makes both halves of that fixable: the run loop
/// comes back between chunks, and there is a phase to draw.
extension KiwiCore {
    /// How long one chunk may hold the main actor, and how long
    /// it hands it back for.
    ///
    /// A click on the menu-bar item waits for the chunk in flight
    /// and then for as many further turns as opening a menu takes,
    /// so what the user feels is the chunk length several times
    /// over — 40/1 measured as a felt lag on device (owner,
    /// 2026-08-12). At 25/8 the run loop owns about a quarter of
    /// boot, which costs roughly a third more wall clock and is
    /// the trade #801 exists to make: an accessory app that is
    /// present must answer.
    ///
    /// The work figure is a floor on the real chunk length, not a
    /// ceiling: one app's AX work is indivisible, so a chunk
    /// overruns by whatever that app costs — bounded by
    /// `EventLoop.bootAppBudget`, and reported per chunk by
    /// `EventLoop.slowChunkReport` when it happens.
    static let bootChunkBudget: Duration = .milliseconds(25)

    /// The gap between chunks. Deliberately not zero: a zero
    /// sleep resumes off the main queue, which the run loop may
    /// drain repeatedly within one pass — the continuation would
    /// then starve exactly the event handling the chunking exists
    /// to free. A sleep is a timer, so the run loop advances.
    static let bootChunkPause: Duration = .milliseconds(8)

    /// The gap before each deferred app's completing reconcile.
    ///
    /// Deliberately far longer than a chunk pause: this is an
    /// UNBUDGETED reconcile of an app that has already proven it
    /// blocks for seconds, run on the main actor. At the chunk
    /// pause it landed 8 ms after the mark went bright — the
    /// exact moment the user first reaches for a menu that has
    /// just started answering. 1.5 s puts it after that, and the
    /// windows it adopts are late by construction anyway (their
    /// app answered nothing in time).
    static let deferredAppPause: Duration = .milliseconds(1500)

    /// Loads the config and starts window management.
    ///
    /// Returns once the first chunk is done — the rest of the
    /// scan and the whole tail run from `.bootScan`
    /// continuations. Callers that used to treat this as "the app
    /// is managing windows now" must read `bootPhase` instead
    /// (#802); `onBootPhaseChange` is the push half of it.
    ///
    /// Phases are signposted and summarized through `onLog`
    /// (#672): boot cost lives almost entirely in the AX scans
    /// under `loadConfig` and the chunked scan, and the field
    /// evidence for a hung app is a duration, so every boot
    /// leaves one on record.
    public func start() {
        let signposter = BootSignpost.signposter
        boot.reachedReady = false
        boot.interval = signposter.beginInterval("boot")
        boot.began = ContinuousClock.now
        armMachineSeams()
        let config = signposter.beginInterval("loadConfig")
        loadConfig()
        signposter.endInterval("loadConfig", config)
        boot.configDone = ContinuousClock.now
        sleepWake.start()
        // One retile for the whole scan instead of one per
        // discovered window (#672): windows fold into state as
        // the events arrive, geometry lands once in the tail.
        defersEventRetiles = true
        defersWindowRuleReconcileToSweep = true
        guard eventLoop.beginScan() else {
            // Unreachable today — `startManaging()` runs at launch
            // or on a false→true permission transition, and a
            // revoke calls `stop()` first — but silent on every
            // count if it ever is reached: no tail, no phase, and
            // an open `boot` span. Say so and close the span.
            defersEventRetiles = false
            defersWindowRuleReconcileToSweep = false
            onLog("boot: refused — the event loop is running")
            closeBootInterval()
            return
        }
        boot.publish(
            .scanning(scanned: 0, total: eventLoop.bootScan.total)
        )
        driveBootScan()
    }

    /// One chunk of the startup scan, then either the tail or a
    /// continuation. The first chunk runs inside `start()`, so a
    /// light session (#681's ~1.5 s baseline) still boots in one
    /// turn and pays nothing for the machinery.
    private func driveBootScan() {
        driveChunkedPass(
            onChunk: { [weak self] progress in
                self?.boot.publish(
                    .scanning(
                        scanned: progress.scanned,
                        total: progress.total
                    )
                )
            },
            onFinish: { [weak self] in self?.finishBoot() }
        )
    }

    /// Runs the open pass one chunk at a time: `onChunk` for a
    /// chunk with work still behind it, `onFinish` on the turn the
    /// queue empties — never both for one chunk, so an epilogue
    /// and a progress step cannot double up on the same turn.
    ///
    /// One driver for both chunked passes (the scan and the
    /// startup sweep): they differ in what they queue and in their
    /// epilogue, not in how they yield, and two copies of a yield
    /// loop is two places for the cadence to drift. The deferred
    /// slot comes from the open pass itself
    /// (`BootScanPass.deferredKey`) rather than from the call
    /// site, so two passes cannot be handed one slot.
    func driveChunkedPass(
        onChunk: (@MainActor (BootScanProgress) -> Void)? = nil,
        onFinish: @escaping @MainActor () -> Void
    ) {
        let key = eventLoop.bootScan.pass.deferredKey
        let progress = eventLoop.scanChunk(
            budget: Self.bootChunkBudget
        )
        guard !progress.finished else {
            onFinish()
            return
        }
        onChunk?(progress)
        deferred.schedule(key, after: Self.bootChunkPause) {
            [weak self] in
            self?.driveChunkedPass(
                onChunk: onChunk,
                onFinish: onFinish
            )
        }
    }

    /// Everything that needs the whole desk known: the first
    /// arrangement, the previous session's, and the services and
    /// nets that run for the rest of the session.
    private func finishBoot() {
        boot.scanDone = ContinuousClock.now
        defersEventRetiles = false
        // The per-event #193 pile restore was suppressed with the
        // retiles, so re-arm it once here — it self-gates on
        // track + actual overflow.
        retile()
        scheduleTrackZOrderRestoreIfOverflowing()
        mouse.start()
        // The scan discovered windows in AX order; put back the
        // arrangement of the previous session.
        let signposter = BootSignpost.signposter
        let restoreSpan =
            signposter.beginInterval("sessionRestore")
        if let session = crash.consumeSession() {
            restore(session)
            activateSpaceOfFocusedWindow()
            seedStartupFocus()
            // Same contract as every other space switch: force
            // past the tolerance check, respect the space-switch
            // animation setting (coordinated out+in, #207), and
            // tell bus subscribers (the bar) where we landed.
            spaceSwitchRetile()
            emitSpaceChange()
            onLog("restored previous session arrangement")
        }
        signposter.endInterval("sessionRestore", restoreSpan)
        crash.start()
        do {
            try socket.start()
        } catch {
            onLog("socket server failed: \(error)")
        }
        scheduleStartupSweep()
        // Paired with the arm above, never with a phase: the
        // window-rule skip is valid exactly while nothing has
        // armed the pass that heals it (#836).
        defersWindowRuleReconcileToSweep = false
        scheduleAdoptionHeal()
        drainDeferredBootApps()
        closeBootInterval()
        logBootSummary()
        boot.reachedReady = true
        boot.publish(.ready)
    }

    /// The apps a per-app budget cut short (#803), completed
    /// after boot and unbudgeted — one per turn, so a second slow
    /// app cannot re-block the run loop the boot just freed.
    /// Deferral *with completion*, never abandonment: an
    /// unattached app's windows must eventually be adopted, which
    /// is what #675's census-gated heal exists to guarantee and
    /// what this spares it.
    /// Called by BOTH passes' epilogues — the scan's tail and the
    /// sweep's. The sweep budgets too, so a ledger taken only
    /// here would leave a sweep-deferred app sitting untaken until
    /// `stop()` discarded it: abandoned to #675's heal, which is
    /// the outcome deferral exists to spare it (code review,
    /// 2026-08-12).
    ///
    /// Internal, not private: `BootPhaseTests`
    /// (`aDeferredAppCompletesOnePerTurn`) drives the drain
    /// directly — a real boot is not test-drivable.
    func drainDeferredBootApps() {
        drainDeferredBootApps(
            Array(eventLoop.takeDeferredBootApps())
        )
    }

    /// APPENDS, then runs the chain if it is not already running.
    ///
    /// Both epilogues call this, and they overlap: with two
    /// scan-deferred apps the boot tail's chain is still working
    /// through them when the sweep ends (each link is an
    /// unbudgeted multi-second reconcile by construction). A
    /// second chain started on the same deferred key would cancel
    /// the first mid-queue and abandon its remainder — the exact
    /// thing "deferral WITH completion" rules out (code review,
    /// 2026-08-12).
    func drainDeferredBootApps(_ queue: [(pid_t, AppRef)]) {
        guard !queue.isEmpty else { return }
        // "Is a chain already running" is DERIVED from the queue
        // rather than stored beside it — one fact, not two that
        // can disagree. The precondition that makes the
        // derivation safe: nothing between the `removeFirst()`
        // below and its `scheduleNextDeferredApp()` suspends, so
        // the queue is empty-with-a-live-chain only inside one
        // synchronous body. An `await` added there would buy a
        // second chain (architect review, 2026-08-12).
        let wasRunning = !eventLoop.bootScan.pendingDrain.isEmpty
        eventLoop.bootScan.pendingDrain.append(contentsOf: queue)
        guard !wasRunning else { return }
        scheduleNextDeferredApp()
    }

    private func scheduleNextDeferredApp() {
        guard !eventLoop.bootScan.pendingDrain.isEmpty else { return }
        deferred.schedule(
            .deferredBootApps,
            after: Self.deferredAppPause
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning,
                !self.eventLoop.bootScan.pendingDrain.isEmpty
            else { return }
            let (pid, ref) = self.eventLoop.bootScan.pendingDrain
                .removeFirst()
            let begin = ContinuousClock.now
            // `coalesceTabs: false`, exactly as the pass step
            // this completes passed it: this is the same bulk
            // discovery, so a window closed between the abort and
            // now must not false-merge with an appearing sibling
            // at the same frame (#308).
            self.eventLoop.reconcile(
                pid: pid,
                app: ref,
                coalesceTabs: false
            )
            let ms = begin.duration(to: .now).wholeMilliseconds
            self.onLog(
                "deferred app: \(ref.bundleID ?? ref.name) "
                    + "completed in \(ms)ms"
            )
            // Its windows are new to the layout, so the
            // arrangement they belong in has to be recomputed —
            // the same reason the scan's own tail retiles once.
            self.retile()
            self.scheduleNextDeferredApp()
        }
    }

    /// Ends the `boot` span if one is open. Internal so `stop()`
    /// can close a boot it interrupted: an unclosed span outlives
    /// the run and the next `start()` opens a second one, which is
    /// the argument `EventLoop.stop()` already writes out for the
    /// pass's own interval.
    func closeBootInterval() {
        guard let interval = boot.interval else { return }
        BootSignpost.signposter.endInterval("boot", interval)
        boot.interval = nil
    }

    private func logBootSummary() {
        let now = ContinuousClock.now
        let began = boot.began ?? now
        let configDone = boot.configDone ?? began
        let scanDone = boot.scanDone ?? configDone
        let configMs =
            began.duration(to: configDone).wholeMilliseconds
        let scanMs =
            configDone.duration(to: scanDone).wholeMilliseconds
        let tailMs = scanDone.duration(to: now).wholeMilliseconds
        let totalMs = began.duration(to: now).wholeMilliseconds
        onLog(
            "boot: config \(configMs)ms, scan \(scanMs)ms, "
                + "restore+services \(tailMs)ms, "
                + "total \(totalMs)ms"
        )
    }
}
