import Foundation
import KiwiDeskCore
import Sparkle
import Testing

@testable import KiwiDesk

/// The update channel's state (#1536): what the Home footer and
/// the About sheet read through one store, and how Sparkle's
/// cycle outcomes classify into it.
///
/// `@MainActor` because the store and the updaters are; the suite
/// spends nothing else there — no Sparkle updater is built.
@Suite("Update state")
@MainActor
struct UpdateStateTests {
    @Test("An inert updater's channel is unavailable, and says so")
    func inertUpdaterIsUnavailable() {
        let updater = NoUpdater()
        #expect(updater.updates.state == .unavailable)
        #expect(!updater.canCheckForUpdates)
    }

    @Test("The store publishes what it is set to")
    func storeHoldsItsState() {
        let store = UpdateStateStore()
        #expect(store.state == .unavailable)
        store.set(.checking)
        #expect(store.state == .checking)
        store.set(.available(version: "1.5.0"))
        #expect(store.state == .available(version: "1.5.0"))
    }

    @Test("Only a fetch failure reads as offline")
    func fetchFailuresAreClassified() {
        func sparkle(_ code: SUError) -> NSError {
            NSError(domain: SUSparkleErrorDomain, code: Int(code.rawValue))
        }
        #expect(
            UpdateCycleObserver.isFetchFailure(
                NSError(
                    domain: NSURLErrorDomain,
                    code: NSURLErrorNotConnectedToInternet
                )
            )
        )
        #expect(UpdateCycleObserver.isFetchFailure(sparkle(.appcastError)))
        #expect(UpdateCycleObserver.isFetchFailure(sparkle(.downloadError)))
        // A dismissed prompt or a refused install is not "offline".
        #expect(
            !UpdateCycleObserver.isFetchFailure(
                sparkle(.installationCanceledError)
            )
        )
        #expect(!UpdateCycleObserver.isFetchFailure(sparkle(.noUpdateError)))
        #expect(
            !UpdateCycleObserver.isFetchFailure(
                NSError(domain: "app.kiwidesk.test", code: 1)
            )
        )
    }

    @Test("The up-to-date sentence carries the last check, relative")
    func upToDateSentenceIsDated() {
        LocalizationManager.shared.select("en")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let dated = UpdateStateRow.upToDateSentence(twoHoursAgo, now: now)
        #expect(dated.hasPrefix("Up to date · last checked "))
        #expect(dated.contains("2 hours ago"))
        #expect(UpdateStateRow.upToDateSentence(nil, now: now) == "Up to date")
    }
}
