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

    /// Whether a process still runs: what tells a record
    /// LaunchServices loses for a moment from one that is gone. A
    /// zombie its parent has not reaped is gone — read through
    /// `sysctl`, since `proc_pidinfo` answers ESRCH for one while
    /// `kill(pid, 0)` still answers 0 (macOS 27.0, 2026-09-30).
    var runs: @MainActor (pid_t) -> Bool = { pid in
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0
        else { return kill(pid, 0) == 0 || errno == EPERM }
        return size > 0 && Int32(info.kp_proc.p_stat) != SZOMB
    }

    /// Whether LaunchServices calls the process at this pid
    /// active — asked by the REAL pid it names the process, where
    /// an announcement names the app; nil without a record.
    var isActive: @MainActor (pid_t) -> Bool? = { pid in
        NSRunningApplication(processIdentifier: pid)?.isActive
    }

    /// Pids the running-app list does not carry, with their bundle
    /// ids — the only processes a sibling can be.
    private(set) var unlisted: [pid_t: String] = [:]
    /// Every observed process as it last read, so neither the
    /// ownership gate nor a sibling check asks LaunchServices
    /// what attach already knew.
    private(set) var observed: [pid_t: RunningApp] = [:]
    /// Observed processes whose record is missing right now, so
    /// one absence logs once.
    private(set) var unrecorded: Set<pid_t> = []

    mutating func record(_ app: RunningApp) {
        unlisted[app.pid] = app.ref.bundleID
    }

    mutating func note(_ app: RunningApp) {
        observed[app.pid] = app
        unrecorded.remove(app.pid)
    }

    /// Whether this absence is news.
    mutating func noteUnrecorded(_ pid: pid_t) -> Bool {
        unrecorded.insert(pid).inserted
    }

    mutating func forget(pid: pid_t) {
        unlisted[pid] = nil
        observed[pid] = nil
        unrecorded.remove(pid)
    }

    mutating func forgetAll() {
        unlisted = [:]
        observed = [:]
        unrecorded = []
    }
}

extension EventLoop {
    /// The frontmost app's pid, the one frontmost chain (#292,
    /// #1322). An app listed without a pid is its unlisted
    /// process of that bundle; with several, the one whose
    /// window is front-most; with none known, no reading.
    func frontmostProcess() -> pid_t? {
        processIdentity.frontmostApp().flatMap(process(of:))
    }

    /// The process an app record names: its own pid, else its
    /// unlisted process of that bundle — with several, the one
    /// whose TRACKED window is front-most, since a shadow comes
    /// forward as its process steps back.
    func process(of app: RunningApp) -> pid_t? {
        guard !Self.isProcessID(app.pid) else { return app.pid }
        let bundleID = app.ref.bundleID
        let candidates = Set(
            processIdentity.unlisted.filter { $0.value == bundleID }
                .keys
        )
        guard candidates.count > 1 else { return candidates.first }
        return processIdentity.frontToBack().first {
            candidates.contains($0.pid)
                && elements[$0.pid]?[$0.id] != nil
        }?.pid
    }

    /// A process's activation policy, the one reading the
    /// ownership gates and the float verdicts take. LaunchServices
    /// loses a running process's record for a moment as its app
    /// activates (device, 2026-09-30), so a missing record is
    /// `.prohibited` only once the process is gone; until then
    /// the policy last read stands.
    func policy(of pid: pid_t) -> NSApplication.ActivationPolicy {
        let known = processIdentity.observed[pid]
        if let policy = activationPolicy(pid) {
            if let known {
                processIdentity.note(
                    RunningApp(
                        pid: pid,
                        activationPolicy: policy,
                        ref: known.ref
                    )
                )
            }
            return policy
        }
        guard let known, processIdentity.runs(pid) else {
            return .prohibited
        }
        if processIdentity.noteUnrecorded(pid) {
            onLog(
                "ownership: pid \(pid) runs without a "
                    + "LaunchServices record — kept"
            )
        }
        return known.activationPolicy
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
        // Ahead of any reuse of a number that stopped running.
        forgetExitedUnlisted()
        return listed + unlisted
    }

    /// Drops every unlisted pid the process table no longer holds.
    private func forgetExitedUnlisted() {
        for pid in processIdentity.unlisted.keys
        where !processIdentity.runs(pid) {
            processIdentity.forget(pid: pid)
        }
    }

    /// A terminate announced without a pid: retire every observed
    /// process that no longer runs, which is the one it meant.
    func retireExitedObservers() {
        // By the process table, never by LaunchServices' record,
        // which goes missing for a running process too.
        for pid in observers.keys.sorted()
        where !Self.isOwnProcess(pid) && !processIdentity.runs(pid) {
            onLog("app exit: pid \(pid) gone, unannounced — detached")
            detach(pid: pid, restoreEnhancedUI: false)
            onEvent(.appTerminated(pid: pid))
        }
        // An unlisted pid that never attached has no observer.
        forgetExitedUnlisted()
    }

    /// An activation announced without a pid that names no
    /// unlisted process either: no reading, so the provenance
    /// gate fails open.
    func noteUnnamedActivation(_ app: RunningApp) {
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
        processIdentity.observed[pid]?.ref.bundleID
            ?? processIdentity.unlisted[pid]
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

/// What the app-lifecycle funnels (`syncObservation`, `attach`,
/// the startup scan, `reconcileAll`) need from a running app.
/// A snapshot value, not the live `NSRunningApplication`, so a
/// test can fabricate one for a made-up pid and drive the
/// funnels through the machine seams (#672 review).
struct RunningApp {
    let pid: pid_t
    let activationPolicy: NSApplication.ActivationPolicy
    let ref: AppRef

    init(
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        ref: AppRef
    ) {
        self.pid = pid
        self.activationPolicy = activationPolicy
        self.ref = ref
    }

    init(_ app: NSRunningApplication) {
        self.init(
            pid: app.processIdentifier,
            activationPolicy: app.activationPolicy,
            ref: AppRef(app)
        )
    }
}

extension AppRef {
    /// Captures identity + display name from a live app handle.
    init(_ app: NSRunningApplication) {
        self.init(
            bundleID: app.bundleIdentifier,
            name: app.localizedName ?? "?"
        )
    }

    /// Re-derives identity from a pid alone (reconcile paths
    /// that only hold the process id). An app that has since
    /// exited yields a nil bundle id and a `"?"` name — so it
    /// matches no rule, which is the correct outcome for a
    /// process that is gone.
    init(pid: pid_t) {
        let app = NSRunningApplication(processIdentifier: pid)
        self.init(
            bundleID: app?.bundleIdentifier,
            name: app?.localizedName ?? "?"
        )
    }
}
