import Foundation

/// The away arm of Open or Focus (#1146): an app with nothing up
/// on any shown Desktop but a window up on an away one is REACHED
/// — the Desktop is switched over the bridge and the window is
/// owed its focus, paid at its arrival (`followFocus`, the #1007
/// shape) — rather than un-parking a local window or launching a
/// duplicate. Without the bridge the branch stands down and the
/// pre-#1146 path runs.
extension KiwiCore {
    /// An app's away windows that are UP, each with its Desktop,
    /// and the ONE topology reading they were resolved in.
    struct AwayReach {
        let windows: [(window: AwayWindow, desktop: Int)]
        let snapshot: DesktopSnapshot
    }

    /// Nil when the app has no away entry or no census can be
    /// read — the topology is read only where an entry exists.
    func awayReach(bundleID: String) -> AwayReach? {
        let away = awayWindows(bundleID: bundleID)
        guard !away.isEmpty else { return nil }
        let snapshot = NativeSpaces.desktopSnapshot()
        guard let census = desktopMemory.readCensus(snapshot.spaces) else {
            return nil
        }
        let windows = away.compactMap { entry -> (AwayWindow, Int)? in
            guard let host = census.hosts[entry.id],
                host.isUp, census.isAway(entry.id),
                let number = snapshot.number(of: host.space)
            else { return nil }
            return (entry, number)
        }
        return AwayReach(windows: windows, snapshot: snapshot)
    }

    /// Switches to `desktop` for `window` and owes it the focus.
    /// False when the bridge is absent or refused the switch —
    /// the caller then takes its ordinary path.
    @discardableResult
    func reachAwayWindow(
        _ window: AwayWindow,
        desktop: Int,
        snapshot: DesktopSnapshot,
        verb: String
    ) -> Bool {
        guard canDriveDesktops,
            let target = Self.desktopTarget(
                number: desktop,
                in: snapshot
            )
        else { return false }
        switch switchDesktop(to: target, verb: verb) {
        case .switched:
            followFocus.record(window.id)
            onLog(
                "\(verb): reaching w\(window.id.raw) "
                    + "(\(window.appName)) on Desktop \(desktop) — "
                    + "focus owed at its arrival"
            )
            scheduleReachReap(pid: window.pid)
            return true
        case .alreadyShown, .refused:
            return false
        }
    }

    /// The follow's own 700 ms reap (`departEagerly`), for the
    /// window that composites after the settle's arrival sweep.
    private func scheduleReachReap(pid: pid_t) {
        deferred.schedule(
            .awayReachReap,
            after: .milliseconds(700)
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning else { return }
            self.eventLoop.reconcile(pid: pid, app: AppRef(pid: pid))
            self.retile(animated: true)
        }
    }
}
