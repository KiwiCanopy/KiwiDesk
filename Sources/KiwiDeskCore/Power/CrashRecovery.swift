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
    /// The login session a write stamps and a read must match
    /// (#1385, `LoginSession`).
    public var loginSession: () -> Int32? = LoginSession.current
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
    /// private center. Read at `start()`.
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
    /// The recent autosaves and departures the freeze rolls back
    /// over (#1385, `LogoutRollback`), on `now`.
    private(set) var rollback = LogoutRollback()
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
        if !preservingSession, let snapshot = capture() {
            write(snapshot, to: sessionURL)
        }
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Consumes and deletes the saved session snapshot, returned
    /// if `readGated` admits it.
    public func consumeSession() -> StateSnapshot? {
        defer {
            try? FileManager.default.removeItem(at: sessionURL)
        }
        return readGated(sessionURL, kind: "session")
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
        let crashed = readGated(fileURL, kind: "crash")
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
        let at = now()
        frozenAt = at
        onLog("autosave frozen: logout or power-off began")
        // macOS quit the apps before this notice (#1385): put back
        // the autosave written before their closes.
        guard let kept = rollback.preBurst(at: at),
            write(kept.snapshot, to: fileURL)
        else { return }
        let age = Int(at.timeIntervalSince(kept.at))
        onLog(
            "autosave rolled back \(age)s, before the logout's "
                + "closes: \(kept.snapshot.windows.count) windows"
        )
    }

    /// One window left (#1385): `closed` is the gone handler's
    /// `closed` arm, never re-derived here.
    func noteDeparture(closed: Bool) {
        rollback.noteDeparture(closed: closed, at: now())
    }

    /// Writes one snapshot now (also called by the timer), unless
    /// a logout froze it.
    public func autosave() {
        guard !isFrozenForLogout() else { return }
        guard let snapshot = captureState() else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard write(snapshot, to: fileURL) else { return }
        rollback.noteAutosave(snapshot, at: now())
        onAutosaved()
    }

    /// Writes `snapshot` stamped with this login session (#1385);
    /// true only when the file landed. An unreadable session
    /// refuses the write and keeps the file there: a stamp-less
    /// file reads as an older build's.
    @discardableResult
    private func write(_ snapshot: StateSnapshot, to url: URL) -> Bool {
        guard let session = loginSession() else {
            onLog("login session unreadable; snapshot not written")
            return false
        }
        var stamped = snapshot
        stamped.loginSession = session
        guard let data = try? JSONEncoder().encode(stamped)
        else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
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

    /// The reading every snapshot writer asks (#1385): true
    /// inside `logoutFreezeBound` of a freeze. The first read past
    /// the bound lifts the freeze and logs that it did.
    func isFrozenForLogout() -> Bool {
        guard let frozenAt else { return false }
        let age = now().timeIntervalSince(frozenAt)
        if age <= Self.logoutFreezeBound { return true }
        self.frozenAt = nil
        onLog("autosave resumed: the logout did not proceed")
        return false
    }

    /// The read both files take: decoded, then dropped unless
    /// written this boot (#633) and in this login session (#1385),
    /// since a logout without a reboot reuses window ids.
    private func readGated(_ url: URL, kind: String) -> StateSnapshot? {
        guard let data = try? Data(contentsOf: url),
            let snapshot = try? JSONDecoder().decode(
                StateSnapshot.self,
                from: data
            )
        else { return nil }
        guard snapshot.capturedAt >= bootTime() else {
            onLog("\(kind) snapshot predates this boot; discarded")
            return nil
        }
        guard isThisLogin(snapshot) else {
            onLog(
                "\(kind) snapshot is from another login session; "
                    + "discarded"
            )
            return nil
        }
        return snapshot
    }

    /// A stamp matches only a readable, equal live id. An
    /// unstamped file is an older build's: admitted only as its
    /// announced relaunch (#930), in-place and inside its bound.
    private func isThisLogin(_ snapshot: StateSnapshot) -> Bool {
        guard let stamp = snapshot.loginSession else {
            return snapshot.carriesSessions
                && now().timeIntervalSince(snapshot.capturedAt)
                    <= Self.inPlaceSessionBound
        }
        return stamp == loginSession()
    }
}
