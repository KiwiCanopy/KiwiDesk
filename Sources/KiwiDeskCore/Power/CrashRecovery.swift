import Foundation

/// Window state persistence across unclean shutdowns and restarts.
@MainActor
public final class CrashRecovery {
    /// Autosave interval in seconds.
    public var interval: TimeInterval = 30

    public var captureState: @MainActor () -> StateSnapshot? =
        { nil }
    public var restoreState: @MainActor (StateSnapshot) -> Void =
        { _ in }
    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// Boot time provider to discard stale pre-boot window IDs (#633).
    public var bootTime: () -> Date = SystemBoot.time

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

    /// Restores after an unclean shutdown, then begins autosaving (#633).
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
        // First autosave immediately: the session file was
        // already consumed by this launch, so a crash inside the
        // first interval would lose the arrangement (#633).
        autosave()
    }

    /// Clean shutdown: stops timer and writes the session
    /// snapshot. `preservingSession: true` skips the save — boot
    /// is the case (#801): a quit mid-scan would write a fraction
    /// of the desk over the arrangement this launch had not
    /// restored yet. The crash marker still goes.
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
            onLog(
                "crash snapshot predates this boot; discarded"
            )
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        return snapshot
    }
}
