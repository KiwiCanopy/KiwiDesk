import Foundation
import Sparkle

/// What the update channel last said (#1536) — read by the Home
/// footer and the About sheet through the one `UpdateStateRow`.
enum UpdateState: Equatable {
    /// No channel: an unbundled run, or no feed in the bundle.
    case unavailable
    /// No verdict this session: only WHEN the channel last checked
    /// is known, never what it found.
    case notChecked(lastChecked: Date?)
    case upToDate(lastChecked: Date?)
    /// Our own check, in flight. A scheduled check is not
    /// narrated (design-decisions ▸ #1536).
    case checking
    case available(version: String)
    /// The check itself failed — appcast unreachable, download
    /// broken. Retryable, so its control stays enabled.
    case failed

    /// The state at the user's own check: a found update keeps
    /// its sentence, since the same door brings the waiting prompt
    /// forward rather than checking again.
    var onOwnCheck: UpdateState {
        if case .available = self { return self }
        return .checking
    }

    /// One cycle outcome folded in — pure, so every arm is pinned
    /// by `UpdateStateTests` without a Sparkle updater.
    func after(
        _ outcome: UpdateCycleOutcome,
        lastChecked: Date?
    ) -> UpdateState {
        switch outcome {
        case .found(let version):
            return .available(version: version)
        case .notFound:
            return .upToDate(lastChecked: lastChecked)
        case .aborted(let error):
            // Sparkle aborts a scheduled check too; only our own
            // is narrated, so only `.checking` may turn `.failed`.
            guard self == .checking else { return self }
            return UpdateCycleObserver.isFetchFailure(error)
                ? .failed : self
        case .finished(let error):
            // Only our own check is still open here; a found
            // update or an abort already answered.
            guard self == .checking else { return self }
            if let error, UpdateCycleObserver.isFetchFailure(error) {
                return .failed
            }
            return .upToDate(lastChecked: lastChecked)
        }
    }
}

/// A Sparkle cycle's outcome, as the delegate hears it.
enum UpdateCycleOutcome {
    case found(version: String)
    case notFound
    case aborted(any Error)
    case finished((any Error)?)
}

/// The one home of `UpdateState`, observed by the views that draw
/// it. `updatePending` (#1013) is a different fact — a scheduled
/// update waiting behind the gentle reminder — and stays on the
/// prompt policy.
@MainActor
final class UpdateStateStore: ObservableObject {
    @Published private(set) var state: UpdateState

    init(_ state: UpdateState = .unavailable) {
        self.state = state
    }

    func set(_ state: UpdateState) {
        self.state = state
    }
}

/// Sparkle's updater delegate: each cycle outcome folded into the
/// store through `UpdateState.after`. Retained by `SparkleUpdater`
/// — `SPUUpdater` holds its delegate weakly.
@MainActor
final class UpdateCycleObserver: NSObject, @MainActor SPUUpdaterDelegate {
    let store: UpdateStateStore
    /// Every item of each appcast Sparkle loads, for the update
    /// window's "everything since your version" (#1542).
    var onAppcast: ([SUAppcastItem]) -> Void = { _ in }

    init(store: UpdateStateStore) {
        self.store = store
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishLoading appcast: SUAppcast
    ) {
        onAppcast(appcast.items)
    }

    func updater(
        _ updater: SPUUpdater,
        didFindValidUpdate item: SUAppcastItem
    ) {
        fold(.found(version: item.displayVersionString), updater)
    }

    func updaterDidNotFindUpdate(
        _ updater: SPUUpdater,
        error: any Error
    ) {
        fold(.notFound, updater)
    }

    func updater(
        _ updater: SPUUpdater,
        didAbortWithError error: any Error
    ) {
        fold(.aborted(error), updater)
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        fold(.finished(error), updater)
    }

    private func fold(_ outcome: UpdateCycleOutcome, _ updater: SPUUpdater) {
        store.set(
            store.state.after(
                outcome,
                lastChecked: updater.lastUpdateCheckDate
            )
        )
    }

    /// A check that could not reach or read the feed — the class
    /// the "you may be offline" sentence describes. A dismissed
    /// prompt or a refused install is not one.
    nonisolated static func isFetchFailure(_ error: any Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }
        guard nsError.domain == SUSparkleErrorDomain else {
            return false
        }
        return [
            SUError.appcastError, .appcastParseError,
            .resumeAppcastError, .downloadError,
        ]
        .map(\.rawValue).contains(OSStatus(nsError.code))
    }
}
