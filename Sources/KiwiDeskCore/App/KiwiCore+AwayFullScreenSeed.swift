import Foundation

/// The boot seed's full-screen arm (#2949): a window already on a
/// native full-screen Space no screen shows when KiwiDesk starts
/// joins the away ledger, so KiwiHub lists it by app name. Its
/// pick brings the app forward (`jumpToFullScreen`'s fallback),
/// since AX lists no element on a hidden full-screen Space.
extension KiwiCore {
    /// Files each UP window of an observed app on a hidden
    /// full-screen Space, UNFILED: a full-screen Space has no
    /// Space of ours to tile into, so the entry names none and
    /// every reader takes its unfiled branch. The census prune
    /// keeps it through `hostedOnFullScreen`. Returns the count.
    func seedFullScreenAway(
        _ census: DesktopCensus,
        refs: [pid_t: AppRef]
    ) -> Int {
        var seeded = 0
        for (id, host) in census.hiddenFullScreenHosts.sorted(by: {
            $0.key.raw < $1.key.raw
        }) {
            guard host.isUp,
                state.windows[id] == nil,
                state.awayWindows[id] == nil,
                eventLoop.observes(pid: host.pid),
                let ref = refs[host.pid]
            else { continue }
            state.awayWindows[id] = AwayWindow(
                id: id,
                pid: host.pid,
                appName: ref.name,
                appBundleID: ref.bundleID,
                nativeSpace: host.space,
                isUp: true
            )
            seeded += 1
        }
        if seeded > 0 {
            onLog("boot census: \(seeded) window(s) on full-screen Spaces")
        }
        return seeded
    }
}
