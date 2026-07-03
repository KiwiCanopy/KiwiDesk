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
    public var onLog: @MainActor (String) -> Void = { _ in }

    private let fileURL: URL
    private var timer: Timer?

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent(
            ".state_snapshot"
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
    }

    /// Clean shutdown: stop autosaving and drop the snapshot
    /// so the next launch does not "restore".
    public func shutdownCleanly() {
        timer?.invalidate()
        timer = nil
        try? FileManager.default.removeItem(at: fileURL)
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
        return try? JSONDecoder().decode(
            StateSnapshot.self,
            from: data
        )
    }
}
