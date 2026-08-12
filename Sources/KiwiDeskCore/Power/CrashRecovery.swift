import Foundation

/// Crash safety net: autosaves the window state every 30
/// seconds; after an unclean shutdown the leftover snapshot is
/// restored (windows of crashed apps are simply skipped and
/// the layout re-tiles naturally).
@MainActor
public final class CrashRecovery {
    /// Autosave interval in seconds.
    public var interval: TimeInterval = 30

    public var captureState: @MainActor () -> StateSnapshot? =
        { nil }
    public var restoreState: @MainActor (StateSnapshot) -> Void =
        { _ in }
    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// A snapshot is meaningful only within the boot that
    /// captured it (#633): WindowServer mints fresh low-integer
    /// `CGWindowID`s per login session, so replaying a pre-boot
    /// snapshot files random new windows into old spaces and
    /// seeds dead ids into the remembered-space map. Both
    /// snapshot files survive a reboot, so both readers gate on
    /// this. The gate is scoped to the *reboot* — a logout →
    /// login on the same boot also remints ids but is not
    /// caught here; accepted as the rare cousin of the dominant
    /// case. Injected so tests pin the boundary instead of
    /// reading the host's boot clock.
    public var bootTime: () -> Date = SystemBoot.time

    private let fileURL: URL
    /// Arrangement saved on CLEAN shutdown, restored on the
    /// next launch (window order per space, active space).
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

    /// Restores after an unclean shutdown, then begins
    /// autosaving.
    public func start() {
        if let snapshot = readSnapshot() {
            onLog(
                "unclean shutdown detected; restoring "
                    + "\(snapshot.windows.count) windows"
            )
            restoreState(snapshot)
        }
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
        // First autosave immediately, not at the interval's
        // end: the session file was already consumed by this
        // launch, so a crash inside the first interval would
        // otherwise lose the arrangement entirely (#633).
        autosave()
    }

    /// Clean shutdown: stop autosaving, save the arrangement
    /// for the next launch, and drop the crash marker so the
    /// next launch does not treat this as a crash.
    ///
    /// `preservingSession: true` skips the save and leaves the
    /// existing file untouched — for a shutdown whose live state
    /// is not an arrangement worth keeping. Boot is the case
    /// (#801): the scan takes several seconds now, and a quit or a
    /// permission revoke mid-scan would write a fraction of the
    /// desk over the arrangement this launch had not restored yet.
    /// The crash marker still goes, because the shutdown itself
    /// was clean.
    public func shutdownCleanly(
        preservingSession: Bool = false
    ) {
        timer?.invalidate()
        timer = nil
        if !preservingSession, let snapshot = captureState(),
            let data = try? JSONEncoder().encode(snapshot)
        {
            try? data.write(to: sessionURL, options: .atomic)
        }
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// The previous session's arrangement, if any. One-shot:
    /// reading deletes the file, so a session is never applied
    /// twice — and a session captured before the current boot
    /// is discarded outright (see `bootTime`).
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

    /// Deletes both snapshot files — the tier-1 escape hatch
    /// (#634). Anything captured EARLIER is gone; the files
    /// regenerate from the live state (the crash marker on the
    /// next autosave tick, the session file at the next clean
    /// quit), which is the point: current state, not a stale
    /// capture.
    public func discardSavedSnapshots() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: sessionURL)
    }

    /// Writes one snapshot now (also called by the timer).
    public func autosave() {
        guard let snapshot = captureState() else { return }
        guard
            let data = try? JSONEncoder().encode(snapshot)
        else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
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
            // A crash file left over from before a reboot
            // (power loss, forced shutdown) — drop it, or the
            // dead ids replay every launch until a clean quit.
            onLog(
                "crash snapshot predates this boot; discarded"
            )
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        return snapshot
    }
}
