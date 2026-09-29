import AppKit

/// Naming a window's process where LaunchServices cannot (#1785):
/// a process an app starts as its own LaunchServices child
/// (Orion's second profile) is listed with pid -1 and its
/// activation announced under the parent's pid, while the
/// WindowServer and AX know the real one.
struct ProcessIdentity {
    /// The app running under a WindowServer pid, keyed by THAT
    /// pid: a child's own `processIdentifier` reads -1 however it
    /// is looked up.
    var appAt: @MainActor (pid_t) -> RunningApp? = { pid in
        NSRunningApplication(processIdentifier: pid).map {
            RunningApp(
                pid: pid,
                activationPolicy: $0.activationPolicy,
                ref: AppRef($0)
            )
        }
    }

    /// The frontmost app as LaunchServices lists it.
    var frontmostApp: @MainActor () -> RunningApp? = {
        NSWorkspace.shared.frontmostApplication.map(RunningApp.init)
    }

    /// On-screen layer-0 windows, front to back.
    var frontToBack: @MainActor () -> [(id: WindowID, pid: pid_t)] =
        AXHelper.onScreenNormalWindowsFrontToBack

    /// Pids the running-app list does not carry, with their bundle
    /// ids — the only processes a sibling can be.
    private(set) var unlisted: [pid_t: String] = [:]

    mutating func record(_ app: RunningApp) {
        unlisted[app.pid] = app.ref.bundleID
    }

    mutating func forget(pid: pid_t) { unlisted[pid] = nil }
    mutating func forgetAll() { unlisted = [:] }
}

extension EventLoop {
    /// The frontmost app's pid, the one frontmost chain (#292,
    /// #1322). An app listed without a pid is its unlisted
    /// process of that bundle; with several, the one whose
    /// window is front-most; with none known, no reading.
    func frontmostProcess() -> pid_t? {
        guard let app = processIdentity.frontmostApp() else {
            return nil
        }
        guard !Self.isProcessID(app.pid) else { return app.pid }
        let bundleID = app.ref.bundleID
        let candidates = Set(
            processIdentity.unlisted.filter { $0.value == bundleID }
                .keys
        )
        guard candidates.count > 1 else { return candidates.first }
        return processIdentity.frontToBack().first {
            candidates.contains($0.pid)
        }?.pid
    }

    /// A pid LaunchServices could not name (-1, or any value
    /// ≤ 0) is never keyed on (#1785).
    nonisolated static func isProcessID(_ pid: pid_t) -> Bool {
        pid > 0
    }

    /// Every running app a pass may attach (#1785): the listed
    /// ones with a real pid, then each window owner the list lacks,
    /// resolved by that pid. `owners` defaults to every pid owning
    /// a layer-0 window on any Desktop; the heal hands its census.
    func liveApps(owners: Set<pid_t>? = nil) -> [RunningApp] {
        let listed = runningApplications().filter {
            Self.isProcessID($0.pid)
        }
        let known = Set(listed.map(\.pid))
        let unlisted = (owners ?? visiblePIDs())
            .filter { Self.isProcessID($0) && !known.contains($0) }
            .sorted()
            .compactMap { processIdentity.appAt($0) }
        for app in unlisted where app.ref.bundleID != nil {
            processIdentity.record(app)
        }
        return listed + unlisted
    }

    /// A terminate announced without a pid: retire every observed
    /// process that no longer runs, which is the one it meant.
    func retireExitedObservers() {
        for pid in observers.keys.sorted()
        where !Self.isOwnProcess(pid)
            && processIdentity.appAt(pid) == nil
        {
            onLog("app exit: pid \(pid) gone, unannounced — detached")
            detach(pid: pid, restoreEnhancedUI: false)
            onEvent(.appTerminated(pid: pid))
        }
        // An unlisted pid that never attached has no observer.
        for pid in processIdentity.unlisted.keys
        where processIdentity.appAt(pid) == nil {
            processIdentity.forget(pid: pid)
        }
    }

    /// An activation announced without a pid: no active-app
    /// reading, so the provenance gate fails open.
    func forgetUnnamedActivation(_ app: RunningApp) {
        onLog(
            "activation: \(app.ref.bundleID ?? app.ref.name) "
                + "announced without a pid"
        )
        lastActivePid = nil
    }

    /// The other observed processes of `pid`'s app.
    func siblingProcesses(of pid: pid_t) -> Set<pid_t> {
        Set(observers.keys.filter { areSiblings(pid, $0) })
    }

    /// Whether two processes are one app's: one of them unlisted
    /// and both of one bundle. A pair of listed processes is
    /// never asked, so an app with one pid pays no lookup.
    func areSiblings(_ pid: pid_t, _ other: pid_t) -> Bool {
        guard pid != other,
            processIdentity.unlisted[pid] != nil
                || processIdentity.unlisted[other] != nil,
            let bundleID = bundle(of: pid)
        else { return false }
        return bundle(of: other) == bundleID
    }

    private func bundle(of pid: pid_t) -> String? {
        processIdentity.unlisted[pid]
            ?? processIdentity.appAt(pid)?.ref.bundleID
    }

    /// An activation of an app running as several processes
    /// reports no focus of its own: the announced pid may be a
    /// sibling's, so each process's own report decides.
    func defersToSiblingReports(_ pid: pid_t) -> Bool {
        let siblings = siblingProcesses(of: pid)
        guard !siblings.isEmpty else { return false }
        onLog(
            "activation: pid \(pid) runs beside "
                + "\(siblings.sorted()) — their own reports decide"
        )
        return true
    }
}
