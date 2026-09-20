import Foundation
import Sparkle

/// What the update channel last said (#1536) — read by the Home
/// footer and the About sheet through the one `UpdateStateRow`.
enum UpdateState: Equatable {
    /// No channel: an unbundled run, or no feed in the bundle.
    case unavailable
    case upToDate(lastChecked: Date?)
    case checking
    case available(version: String)
    /// The check itself failed — appcast unreachable, download
    /// broken. Retryable, so its control stays enabled.
    case failed
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

/// Sparkle's updater delegate: the cycle's outcome, written into
/// the store. Retained by `SparkleUpdater` — `SPUUpdater` holds
/// its delegate weakly.
@MainActor
final class UpdateCycleObserver: NSObject, @MainActor SPUUpdaterDelegate {
    let store: UpdateStateStore

    init(store: UpdateStateStore) {
        self.store = store
    }

    func updater(
        _ updater: SPUUpdater,
        didFindValidUpdate item: SUAppcastItem
    ) {
        store.set(.available(version: item.displayVersionString))
    }

    func updaterDidNotFindUpdate(
        _ updater: SPUUpdater,
        error: any Error
    ) {
        store.set(.upToDate(lastChecked: updater.lastUpdateCheckDate))
    }

    func updater(
        _ updater: SPUUpdater,
        didAbortWithError error: any Error
    ) {
        if Self.isFetchFailure(error) {
            store.set(.failed)
        }
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        guard store.state == .checking else { return }
        store.set(
            error == nil || !Self.isFetchFailure(error!)
                ? .upToDate(lastChecked: updater.lastUpdateCheckDate)
                : .failed
        )
    }

    /// A check that could not reach or read the feed — the class
    /// the "you may be offline" sentence describes. A dismissed
    /// prompt or a refused install is not one.
    static func isFetchFailure(_ error: any Error) -> Bool {
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
