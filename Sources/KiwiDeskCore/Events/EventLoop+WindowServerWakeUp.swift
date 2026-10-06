import Foundation

/// The AX path's WindowServer wake-ups (#1877). Both only ASK an
/// app again; neither tracks, files nor removes a window.
extension EventLoop {
    /// Re-reads the app tracking `id`, off the main actor, when
    /// it still tracks it; reads nothing from WindowServer.
    func windowServerDestroyed(_ id: WindowID) {
        guard isRunning,
            let pid = elements.first(where: { $0.value[id] != nil })?.key
        else { return }
        onLog("wake-up: w\(id.raw) destroyed unanswered, pid \(pid)")
        reconcileOffMain(pid: pid, app: appRef(of: pid))
    }

    /// Reads the census off the main actor, then wakes on it and
    /// calls `done` unless cancelled — `requestHealSweep`'s shape.
    func requestWakeSweep(
        then done: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        nonisolated(unsafe) let read = onScreenNormalWindowIDs
        return Task.detached(priority: .utility) { [weak self] in
            let census = read()
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self?.wakeSweep(census: census)
                done()
            }
        }
    }

    /// The heal's gate without its ledger, as
    /// `reconcileOnScreenArrivals` takes it: a create's window may
    /// not be listed yet, and quieting it here would hush it for
    /// every later tick. Reads go off the main actor; an
    /// unwatched app attaches through the heal's funnel, gated by
    /// the ledger read-only so an ignored agent is walked once.
    func wakeSweep(census: [pid_t: Set<WindowID>]) {
        guard isRunning else { return }
        var unwatched: [pid_t: RunningApp]?
        for pid in census.keys.sorted() where Self.isProcessID(pid) {
            guard let ids = census[pid], !ids.isEmpty else { continue }
            let missing = ids.subtracting(
                Set(elements[pid, default: [:]].keys)
            )
            guard !missing.isEmpty,
                opensGate(pid: pid, missing: missing)
            else { continue }
            if observers[pid] == nil {
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
                syncObservation(for: app, scanWindowsAtAttach: false)
                guard observers[pid] != nil else { continue }
            }
            onLog("wake-up: pid \(pid) shows \(missing.count) untracked")
            reconcileOffMain(pid: pid, app: appRef(of: pid))
        }
    }
}
