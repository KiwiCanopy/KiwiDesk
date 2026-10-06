import AppKit
import ApplicationServices

/// The adoption heal (#675): a WindowServer-census-gated sweep
/// that re-adopts windows every event path missed. The event
/// paths can all go silent at once for a fresh-launch app — the
/// observer's registration can fail without a word, and then no
/// notification, no activation and no space change ever comes
/// for it — so a timed backstop is the only pass *guaranteed*
/// to run. It stays cheap by design: one census snapshot
/// (~1 ms, no AX) per tick, and an AX reconcile only where the
/// census names a window that is not tracked.
extension EventLoop {
    /// One census, one pass over the running apps. The gate is
    /// id MEMBERSHIP, not a count: the tracked set legitimately
    /// holds windows the census excludes (raised-layer transient
    /// overlays; other-desktop windows the on-screen list
    /// drops), so a count comparison lets one such window shadow
    /// a missed document window forever — an untracked census id
    /// cannot be shadowed. Fires a reconcile only for a pid
    /// owning an untracked, un-quieted census id (or one with
    /// windows and no observer at all — a launch-time attach
    /// that failed), and repairs any observer whose app-level
    /// registration failed. Ids a reconcile fails to adopt go
    /// quiet (`healQuiet`), so a permanent mismatch — an ignored
    /// layer-0 panel — stops costing reconciles while it lives.
    ///
    /// What this deliberately cannot heal: a window on another
    /// native desktop. AX and the on-screen census both exclude
    /// it, so it is adopted when its desktop is visited (the
    /// native-space-change `reconcileAll`) —
    /// `docs/accepted-limitations.md` carries the row.
    ///
    /// A watched app answers from its filed record; the running-app
    /// list is walked only for an unwatched app the gate lets in,
    /// since every record in it is a LaunchServices round trip
    /// after any activation (#1936).
    ///
    /// The synchronous door, for a caller with no off-main hop —
    /// the suites; the scheduled heal takes `requestHealSweep`,
    /// since this read waits on WindowServer on the main actor.
    func healSweep() {
        guard isRunning else { return }
        healSweep(census: onScreenNormalWindowIDs())
    }

    /// Reads the census off the main actor, then sweeps on it and
    /// calls `done` unless the returned read was cancelled (#1956):
    /// the read waits for WindowServer to take this process's
    /// pending window updates, which ran up to ~340 ms on the main
    /// actor when a tick met a Space switch. The census may be a
    /// read old at delivery; an id it names that left meanwhile
    /// costs one reconcile and goes quiet. The caller tracks the
    /// task, or teardown cannot cancel it.
    func requestHealSweep(
        then done: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        nonisolated(unsafe) let read = onScreenNormalWindowIDs
        return Task.detached(priority: .utility) { [weak self] in
            let census = read()
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self?.healSweep(census: census)
                done()
            }
        }
    }

    /// One sweep over `census`, a snapshot taken by the caller.
    func healSweep(census: [pid_t: Set<WindowID>]) {
        guard isRunning else { return }
        var quiet: [pid_t: Set<WindowID>] = [:]
        var unwatched: [pid_t: RunningApp]?
        forgetExitedUnlisted()
        for pid in census.keys.sorted() where Self.isProcessID(pid) {
            guard let ids = census[pid], !ids.isEmpty
            else { continue }
            if let observer = observers[pid] {
                let app = appRef(of: pid)
                if observer.needsRegistrationRepair {
                    observer.repairRegistration()
                }
                let tracked = Set(
                    elements[pid, default: [:]].keys
                )
                let missing = ids.subtracting(tracked)
                guard !missing.isEmpty else { continue }
                guard opensGate(pid: pid, missing: missing)
                else {
                    quiet[pid] = missing
                    continue
                }
                reconcile(pid: pid, app: app)
                settleHeal(
                    pid: pid,
                    app: app,
                    missing: missing,
                    quiet: &quiet
                )
            } else {
                guard opensGate(pid: pid, missing: ids) else {
                    quiet[pid] = ids
                    continue
                }
                if unwatched == nil {
                    let walked = liveApps(owners: Set(census.keys))
                    for app in walked {
                        notePolicy(app.activationPolicy, of: app.pid)
                    }
                    unwatched = Dictionary(
                        walked.map { ($0.pid, $0) },
                        uniquingKeysWith: { first, _ in first }
                    )
                }
                guard let app = unwatched?[pid] else { continue }
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
                    // Ignored or prohibited: hush these ids.
                    quiet[pid] = ids
                    continue
                }
                reconcile(pid: pid, app: app.ref)
                settleHeal(
                    pid: pid,
                    app: app.ref,
                    missing: ids,
                    quiet: &quiet
                )
            }
        }
        // Wholesale replace: entries for exited apps, closed
        // windows and healed ids fall away, so the ledger stays
        // bounded by the live mismatches.
        healQuiet = quiet
    }

    /// The session came back (unlock, wake): an AX verdict read
    /// while it rested is no evidence, since a locked session lists
    /// windows whose elements answer as the application (#1285).
    /// The one list of what a return forgets.
    func sessionDidReturn() {
        forgetHealQuiet()
    }

    /// Re-opens the gate for every quieted id; the next heal
    /// asks again.
    func forgetHealQuiet() {
        let count = healQuiet.values.reduce(0) { $0 + $1.count }
        guard count > 0 else { return }
        healQuiet = [:]
        onLog("adoption heal: re-opened \(count) quieted window(s)")
    }

    /// The gate opens only for a missing id that has not already
    /// failed a heal — a quieted id (an ignored panel that will
    /// never track) costs one reconcile total, while any NEW
    /// census id re-opens the gate at once.
    func opensGate(
        pid: pid_t,
        missing: Set<WindowID>
    ) -> Bool {
        !missing.subtracting(healQuiet[pid] ?? []).isEmpty
    }

    /// After a heal reconcile: whichever of the ids the gate
    /// opened for are STILL untracked failed to adopt — hush
    /// exactly those. A heal that adopted something is field
    /// evidence for #675's intermittent repro, so it leaves a
    /// line on record, like the boot scan does.
    private func settleHeal(
        pid: pid_t,
        app: AppRef,
        missing: Set<WindowID>,
        quiet: inout [pid_t: Set<WindowID>]
    ) {
        let tracked = Set(elements[pid, default: [:]].keys)
        let unadopted = missing.subtracting(tracked)
        if !unadopted.isEmpty {
            quiet[pid] = unadopted
        }
        let adopted = missing.count - unadopted.count
        if adopted > 0 {
            let name = app.bundleID ?? app.name
            onLog(
                "adoption heal: \(name) "
                    + "+\(adopted) window(s) tracked"
            )
        }
    }
}
