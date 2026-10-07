import AppKit
import Foundation

/// Window state persistence across unclean shutdowns and restarts.
@MainActor
public final class CrashRecovery {
    /// Autosave interval in seconds.
    public var interval: TimeInterval = 30

    public var captureState: @MainActor () -> StateSnapshot? =
        { nil }
    /// The in-place restart's capture (#930): `captureState` plus
    /// the session memory only an in-place relaunch restores.
    public var captureInPlaceState: @MainActor () -> StateSnapshot? =
        { nil }
    public var onLog: @MainActor (String) -> Void = CoreLog.write
    /// The #1385 measurement and its hook after each autosave
    /// write (`RestoreKeyLog`), removed with it.
    let restoreKeys = RestoreKeyLog()
    var onAutosaved: @MainActor () -> Void = {}

    /// Boot time provider to discard stale pre-boot window IDs (#633).
    public var bootTime: () -> Date = SystemBoot.time
    /// The clock `inPlaceSessionBound` and
    /// `logoutFreezeBound` are measured on.
    public var now: () -> Date = { Date() }

    /// How long after its stop an in-place snapshot's session
    /// memory is still the relaunch's (#930): a relaunch arrives
    /// within its boot scan, seconds; a snapshot a failed relaunch
    /// left for a much later launch restores the arrangement and
    /// starts sizing fresh, as any launch after a quit does.
    public static let inPlaceSessionBound: TimeInterval = 120

    /// Where the logout signal arrives (#1385); a test hands a
    /// private center. A deliberate seam: the other NSWorkspace
    /// observers read the shared center. Read at `start()`.
    public var workspaceCenter: NotificationCenter =
        NSWorkspace.shared.notificationCenter

    /// How long a logout's freeze holds (#1385). macOS posts no
    /// counterpart when an app's refusal cancels the logout, so a
    /// freeze must lift on its own; 7 s is one measured logout. A
    /// logout held open past the bound (a save sheet answered
    /// late) is the accepted loss.
    public static let logoutFreezeBound: TimeInterval = 120

    /// When the logout froze the snapshot writes, or nil (#1385).
    private(set) var frozenAt: Date?
    /// The power-off observer and the center it was added on.
    private(set) var powerOff:
        (token: NSObjectProtocol, center: NotificationCenter)?

    private let fileURL: URL
    private let sessionURL: URL
    private var timer: Timer?

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent(
            ".state_snapshot"
        )
        self.sessionURL = directory.appendingPathComponent(
            ".session_snapshot"
        )
    }

    /// Begins autosaving (#633). The unclean shutdown's restore is
    /// `takeBootSnapshot`'s, taken before boot's first retile
    /// (#930).
    public func start() {
        guard timer == nil else { return }
        let timer = Timer(
            timeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.autosave()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        observePowerOff()
        // First autosave immediately: the session file was
        // already consumed by this launch, so a crash inside the
        // first interval would lose the arrangement (#633).
        autosave()
    }

    /// Clean shutdown: stops timer and writes the session
    /// snapshot. `preservingSession: true` skips the save — boot
    /// is the case (#801): a quit mid-scan would write a fraction
    /// of the desk over the arrangement this launch had not
    /// restored yet. The crash marker still goes. `inPlace` takes
    /// `captureInPlaceState` (#930). While a logout froze the
    /// writes, the stop writes nothing and keeps the autosave, the
    /// desk being emptied by then (#1385); an announced in-place
    /// restart outranks the freeze, its windows still live.
    public func shutdownCleanly(
        preservingSession: Bool = false,
        inPlace: Bool = false
    ) {
        timer?.invalidate()
        timer = nil
        if let powerOff {
            powerOff.center.removeObserver(powerOff.token)
        }
        powerOff = nil
        if !inPlace, isFrozenForLogout() {
            onLog("stopped during a logout; pre-logout autosave kept")
            return
        }
        let capture = inPlace ? captureInPlaceState : captureState
        if !preservingSession, let snapshot = capture(),
            let data = try? JSONEncoder().encode(snapshot)
        {
            try? data.write(to: sessionURL, options: .atomic)
        }
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Consumes and deletes saved session snapshot if from current boot
    /// (#633).
    public func consumeSession() -> StateSnapshot? {
        defer {
            try? FileManager.default.removeItem(at: sessionURL)
        }
        guard let data = try? Data(contentsOf: sessionURL)
        else { return nil }
        guard
            let snapshot = try? JSONDecoder().decode(
                StateSnapshot.self,
                from: data
            )
        else { return nil }
        guard snapshot.capturedAt >= bootTime() else {
            onLog(
                "session snapshot predates this boot; "
                    + "discarded"
            )
            return nil
        }
        return snapshot
    }

    /// The arrangement boot restores (#930): the session a clean
    /// stop wrote, or the autosave an unclean one left — the newer
    /// when both survive. Both files are consumed.
    public func takeBootSnapshot() -> StateSnapshot? {
        var session = consumeSession()
        if let taken = session, taken.carriesSessions,
            now().timeIntervalSince(taken.capturedAt)
                > Self.inPlaceSessionBound
        {
            onLog("in-place session memory too old; dropped")
            session = taken.droppingSessions()
        }
        let crashed = readSnapshot()
        try? FileManager.default.removeItem(at: fileURL)
        guard let crashed,
            session.map({ crashed.capturedAt > $0.capturedAt })
                ?? true
        else { return session }
        onLog(
            "unclean shutdown detected; restoring "
                + "\(crashed.windows.count) windows"
        )
        return crashed
    }

    /// Discards saved snapshot files (#634).
    public func discardSavedSnapshots() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: sessionURL)
    }

    /// Stops the snapshot writes (#1385): the window closes macOS
    /// performs during a logout must not overwrite the last
    /// arrangement. Lifts past `logoutFreezeBound`.
    public func freezeForLogout() {
        frozenAt = now()
        onLog("autosave frozen: logout or power-off began")
    }

    /// Writes one snapshot now (also called by the timer), unless
    /// a logout froze it.
    public func autosave() {
        guard !isFrozenForLogout() else { return }
        guard let snapshot = captureState() else { return }
        guard
            let data = try? JSONEncoder().encode(snapshot)
        else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard (try? data.write(to: fileURL, options: .atomic)) != nil
        else { return }
        onAutosaved()
    }

    /// `NSWorkspace.willPowerOffNotification` — logout, restart
    /// and shut down alike (#1385).
    private func observePowerOff() {
        guard powerOff == nil else { return }
        let center = workspaceCenter
        let token = center.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.freezeForLogout()
            }
        }
        powerOff = (token, center)
    }

    /// The one reading every snapshot writer asks (#1385): true
    /// inside `logoutFreezeBound` of a freeze, lifting it past.
    func isFrozenForLogout() -> Bool {
        guard let frozenAt else { return false }
        let age = now().timeIntervalSince(frozenAt)
        if age <= Self.logoutFreezeBound { return true }
        self.frozenAt = nil
        onLog("autosave resumed: the logout did not proceed")
        return false
    }

    private func readSnapshot() -> StateSnapshot? {
        guard
            let data = try? Data(contentsOf: fileURL)
        else { return nil }
        guard
            let snapshot = try? JSONDecoder().decode(
                StateSnapshot.self,
                from: data
            )
        else { return nil }
        guard snapshot.capturedAt >= bootTime() else {
            onLog(
                "crash snapshot predates this boot; discarded"
            )
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        return snapshot
    }
}
