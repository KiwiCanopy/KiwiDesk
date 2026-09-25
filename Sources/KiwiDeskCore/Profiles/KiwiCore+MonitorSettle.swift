import Foundation

/// Waiting out an in-between screen layout before choosing a
/// profile (#1612). macOS reports one on some transitions —
/// disconnecting a Vision Pro reported the built-in beside it
/// for 0.28–0.34 s, five times of five — and a profile chosen
/// for it is a full apply, reverted a moment later. The
/// measurements are on the issue.
extension KiwiCore {
    /// The quiet a screen-count change waits for: about three
    /// times the longest in-between report measured.
    static let monitorSettleDefault: Duration = .seconds(1)

    /// Whether this display report waits: only a change of
    /// screen COUNT does — an ordinary re-report is never
    /// delayed — never the first report (boot, `priorCount` 0),
    /// and any report while a settle is pending re-arms it.
    func monitorChangeSettles(priorCount: Int) -> Bool {
        guard monitorSettleDelay != nil, priorCount > 0 else {
            return false
        }
        return deferred.isScheduled(.monitorSettle)
            || priorCount != state.workspaces.allDisplays.count
    }

    /// Resolves the Spaces onto the reported screens NOW — the
    /// bars' re-home and the #1175 heal never wait — and chooses
    /// the profile once no report has arrived for
    /// `monitorSettleDelay`, bounded so a flapping topology
    /// still decides.
    func scheduleMonitorSettle() {
        guard let delay = monitorSettleDelay else { return }
        resolveSpaceDisplays()
        deferred.schedule(
            .monitorSettle,
            after: delay,
            maxWait: delay * 5
        ) { [weak self] in
            guard let self else { return }
            // A fired task stays in its slot; clear it so the
            // next report reads "nothing pending".
            self.deferred.cancel(.monitorSettle)
            self.handleMonitorChange()
            self.emitMonitorChange()
            if !self.defersEventRetiles { self.retile() }
        }
    }
}
