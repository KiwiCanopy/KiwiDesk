import Foundation

/// Waiting out an in-between screen layout before choosing a
/// profile (#1612): macOS reports one on some transitions, and a
/// profile chosen for it is a full apply reverted a moment later.
/// A screen-count change resolves the Spaces onto the reported
/// screens at once and owes the profile choice until the reports
/// stop; the measurements are on the issue.
extension KiwiCore {
    /// The quiet a screen-count change waits for: about three
    /// times the longest in-between report measured.
    nonisolated static let monitorSettleDefault: Duration = .seconds(1)

    /// The longest a flapping topology can hold the choice off —
    /// a fixed bound, not a multiple of the delay, so a short test
    /// delay cannot turn it into a synchronous settle mid-burst.
    nonisolated static let monitorSettleBound: Duration = .seconds(5)

    /// Whether a profile choice is owed to a pending settle.
    var monitorSettlePending: Bool {
        deferred.isScheduled(.monitorSettle)
    }

    /// Whether this display report owes a settle: any report while
    /// one is pending, or a change of screen COUNT after the first
    /// report (`priorCount` 0 is boot). A same-count re-report
    /// decides at once.
    func monitorChangeSettles(priorCount: Int) -> Bool {
        monitorSettlePending
            || (priorCount > 0
                && priorCount != state.workspaces.allDisplays.count)
    }

    /// Resolves the Spaces onto the reported screens NOW — the
    /// bars' re-home and the #1175 heal never wait — and settles
    /// once no report has arrived for `timings.monitorSettleDelay`,
    /// bounded so a flapping topology still decides. A nil delay
    /// (tests) settles inline: both steps run, only the wait goes.
    func scheduleMonitorSettle() {
        resolveSpaceDisplays()
        guard let delay = timings.monitorSettleDelay else {
            settleMonitorChange()
            return
        }
        deferred.schedule(
            .monitorSettle,
            after: delay,
            maxWait: max(delay, Self.monitorSettleBound)
        ) { [weak self] in
            self?.settleMonitorChange()
        }
    }

    /// The owed profile choice, and the one retile a settled
    /// change takes — the event's own stands down for it.
    func settleMonitorChange() {
        deferred.cancel(.monitorSettle)
        retireOrphanedHealSeeds()
        handleMonitorChange()
        state.settlingScreens = [:]
        emitMonitorChange()
        if !defersEventRetiles { retile() }
    }

    /// Any profile apply outranks a pending settle — a user's
    /// `load_profile` inside the wait must not be undone when it
    /// fires — while the `monitor_change` it owed still fires.
    func supersedeMonitorSettle() {
        guard monitorSettlePending else { return }
        deferred.cancel(.monitorSettle)
        state.settlingScreens = [:]
        emitMonitorChange()
    }

    /// Each Space's screen fingerprint before a display report
    /// folds — only a report pays for the read.
    func spaceScreens(for event: KiwiEvent) -> [SpaceID: String] {
        guard case .displaysChanged = event else { return [:] }
        var screens: [SpaceID: String] = [:]
        for display in state.workspaces.allDisplays {
            for space in state.workspaces.spaces(on: display.id) {
                screens[space] = display.fingerprint
            }
        }
        return screens
    }
}
