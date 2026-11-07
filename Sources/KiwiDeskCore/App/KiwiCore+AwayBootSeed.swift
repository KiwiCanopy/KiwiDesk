import Foundation

/// The boot seed's one admission (#1146) and its full-screen arm
/// (#2949): a window already on a native full-screen Space no
/// screen shows when KiwiDesk starts joins the away ledger, so
/// KiwiHub lists it by app name. Its pick brings the app forward
/// (`jumpToFullScreen`'s fallback), since AX lists no element on
/// a hidden full-screen Space.
extension KiwiCore {
    /// Files `id` into the ledger when it is UP, untracked, not
    /// filed yet and its app observed; returns whether it did. A
    /// carried filing up there resumes as the departure it was,
    /// observed app or not (`resumeCarriedDeparture`, #2907). The
    /// one assignment site of both boot arms.
    func admitBootAway(
        _ id: WindowID,
        _ host: DesktopCensus.Host,
        refs: [pid_t: AppRef]
    ) -> Bool {
        guard host.isUp, state.windows[id] == nil else { return false }
        state.resumeCarriedDeparture(id)
        guard state.awayWindows[id] == nil,
            eventLoop.observes(pid: host.pid),
            let ref = refs[host.pid]
        else { return false }
        state.awayWindows[id] = AwayWindow(
            id: id,
            pid: host.pid,
            appName: ref.name,
            appBundleID: ref.bundleID,
            nativeSpace: host.space,
            isUp: host.isUp
        )
        return true
    }

    /// Admits each window a hidden full-screen Space shows. It files
    /// no Space of its own: a full-screen Space has no Desktop key,
    /// so the entry is UNFILED unless the snapshot carried a filing.
    /// The census prune keeps it through `hostedOnFullScreen`.
    /// Returns the count.
    func seedFullScreenAway(
        _ census: DesktopCensus,
        refs: [pid_t: AppRef]
    ) -> Int {
        var seeded = 0
        for (id, host) in census.hiddenFullScreenHosts.sorted(by: {
            $0.key.raw < $1.key.raw
        }) where admitBootAway(id, host, refs: refs) {
            seeded += 1
        }
        if seeded > 0 {
            onLog("boot census: \(seeded) window(s) on full-screen Spaces")
        }
        return seeded
    }
}
