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
    /// The clock `inPlaceSessionBound` is measured on.
    public var now: () -> Date = { Date() }

    /// How long after its stop an in-place snapshot's session
    /// memory is still the relaunch's (#930): a relaunch arrives
    /// within its boot scan, seconds; a snapshot a failed relaunch
    /// left for a much later launch restores the arrangement and
    /// starts sizing fresh, as any launch after a quit does.
    public static let inPlaceSessionBound: TimeInterval = 120

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
    /// `captureInPlaceState` (#930).
    public func shutdownCleanly(
        preservingSession: Bool = false,
        inPlace: Bool = false
    ) {
        timer?.invalidate()
        timer = nil
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
        guard (try? data.write(to: fileURL, options: .atomic)) != nil
        else { return }
        onAutosaved()
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
