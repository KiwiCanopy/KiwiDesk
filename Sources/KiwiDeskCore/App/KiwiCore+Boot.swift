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
    /// How long one chunk may hold the main actor. ~40 ms is
    /// under three display frames, so a click on the menu-bar
    /// item lands about when it would on an idle app. It is a
    /// floor on the real chunk length, not a ceiling: one app's
    /// AX work is indivisible and the chunk overruns by whatever
    /// that app costs, bounded by `EventLoop.bootAppBudget`.
    static let bootChunkBudget: Duration = .milliseconds(40)

    /// The gap between chunks. Deliberately not zero: a zero
    /// sleep resumes off the main queue, which the run loop may
    /// drain repeatedly within one pass — the continuation would
    /// then starve exactly the event handling the chunking exists
    /// to free. A 1 ms sleep is a timer, so the run loop
    /// advances.
    static let bootChunkPause: Duration = .milliseconds(1)

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
        guard eventLoop.beginScan() else {
            defersEventRetiles = false
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
            .bootScan,
            onProgress: { [weak self] progress in
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

    /// Runs the open pass one chunk at a time and calls
    /// `onFinish` on the turn its queue empties. One driver for
    /// both chunked passes (the scan and the startup sweep) —
    /// they differ in what they queue and in their epilogue, not
    /// in how they yield, and two copies of a yield loop is two
    /// places for the pause to drift.
    func driveChunkedPass(
        _ key: DeferredTasks.Key,
        onProgress: (@MainActor (BootScanProgress) -> Void)? = nil,
        onFinish: @escaping @MainActor () -> Void
    ) {
        let progress = eventLoop.scanChunk(
            budget: Self.bootChunkBudget
        )
        onProgress?(progress)
        guard !progress.finished else {
            onFinish()
            return
        }
        deferred.schedule(key, after: Self.bootChunkPause) {
            [weak self] in
            self?.driveChunkedPass(
                key,
                onProgress: onProgress,
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
        scheduleAdoptionHeal()
        scheduleDeferredBootApps()
        if let interval = boot.interval {
            signposter.endInterval("boot", interval)
            boot.interval = nil
        }
        logBootSummary()
        boot.publish(.ready)
    }

    /// The apps a per-app budget cut short (#803), completed
    /// after boot and unbudgeted — one per turn, so a second slow
    /// app cannot re-block the run loop the boot just freed.
    /// Deferral *with completion*, never abandonment: an
    /// unattached app's windows must eventually be adopted, which
    /// is what #675's census-gated heal exists to guarantee and
    /// what this spares it.
    private func scheduleDeferredBootApps() {
        drainDeferredBootApps(
            Array(eventLoop.takeDeferredBootApps())
        )
    }

    /// Internal, not private: `DeferredBootAppTests` drives the
    /// drain directly — the scheduling half is otherwise only
    /// reachable through a real boot, which no test drives.
    func drainDeferredBootApps(_ queue: [(pid_t, AppRef)]) {
        guard let (pid, ref) = queue.first else { return }
        let rest = Array(queue.dropFirst())
        deferred.schedule(
            .deferredBootApps,
            after: Self.bootChunkPause
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning else {
                return
            }
            let begin = ContinuousClock.now
            self.eventLoop.reconcile(pid: pid, app: ref)
            let ms = begin.duration(to: .now).wholeMilliseconds
            self.onLog(
                "deferred app: \(ref.bundleID ?? ref.name) "
                    + "completed in \(ms)ms"
            )
            // Its windows are new to the layout, so the
            // arrangement they belong in has to be recomputed —
            // the same reason the scan's own tail retiles once.
            self.retile()
            self.drainDeferredBootApps(rest)
        }
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
