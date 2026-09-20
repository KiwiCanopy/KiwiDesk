import Foundation
import KiwiDeskCore
import Sparkle
import Testing

@testable import KiwiDesk

/// The update channel's state (#1536): what the Home footer and
/// the About sheet read through one store, how Sparkle's cycle
/// outcomes fold into it, and the sentences each state draws.
///
/// `@MainActor` because the store and the updaters are; the suite
/// spends nothing else there — no Sparkle updater is built.
@Suite("Update state")
@MainActor
struct UpdateStateTests {
    private let checked = Date(timeIntervalSince1970: 1_800_000_000)

    private func sparkle(_ code: SUError) -> NSError {
        NSError(domain: SUSparkleErrorDomain, code: Int(code.rawValue))
    }

    private var offline: NSError {
        NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet
        )
    }

    @Test("An inert updater's channel is unavailable, and says so")
    func inertUpdaterIsUnavailable() {
        let updater = NoUpdater()
        #expect(updater.updates.state == .unavailable)
        #expect(!updater.canCheckForUpdates)
    }

    @Test("A found update is kept; every other outcome answers")
    func outcomesFold() {
        let checking = UpdateState.checking
        #expect(
            checking.after(.found(version: "1.5.0"), lastChecked: checked)
                == .available(version: "1.5.0")
        )
        #expect(
            checking.after(.notFound, lastChecked: checked)
                == .upToDate(lastChecked: checked)
        )
        #expect(
            checking.after(.finished(nil), lastChecked: checked)
                == .upToDate(lastChecked: checked)
        )
        #expect(
            checking.after(.finished(offline), lastChecked: checked)
                == .failed
        )
        #expect(
            checking.after(.aborted(offline), lastChecked: checked)
                == .failed
        )
        // A refused install is not a failed CHECK.
        #expect(
            checking.after(
                .aborted(sparkle(.installationCanceledError)),
                lastChecked: checked
            ) == .checking
        )
    }

    @Test("A found version survives the cycle's end and a dismissal")
    func availableSurvivesTheCycleEnd() {
        let available = UpdateState.available(version: "1.5.0")
        #expect(
            available.after(.finished(nil), lastChecked: checked)
                == available
        )
        #expect(
            available.after(
                .aborted(sparkle(.installationCanceledError)),
                lastChecked: checked
            ) == available
        )
        // Our own check keeps the sentence: the same door brings
        // the waiting prompt forward.
        #expect(available.onOwnCheck == available)
        #expect(UpdateState.upToDate(lastChecked: nil).onOwnCheck == .checking)
        #expect(
            UpdateState.notChecked(lastChecked: nil).onOwnCheck == .checking
        )
    }

    @Test("A scheduled check that was never narrated does not fail Home")
    func unnarratedCycleEndLeavesTheStateAlone() {
        let dated = UpdateState.notChecked(lastChecked: checked)
        #expect(dated.after(.finished(offline), lastChecked: checked) == dated)
        #expect(
            dated.after(.notFound, lastChecked: checked)
                == .upToDate(lastChecked: checked)
        )
    }

    @Test("Only a fetch failure reads as offline")
    func fetchFailuresAreClassified() {
        #expect(UpdateCycleObserver.isFetchFailure(offline))
        #expect(UpdateCycleObserver.isFetchFailure(sparkle(.appcastError)))
        #expect(UpdateCycleObserver.isFetchFailure(sparkle(.downloadError)))
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

    @Test("The sentences date the last check, and claim nothing early")
    func sentencesAreDated() {
        LocalizationManager.shared.select("en")
        let now = checked.addingTimeInterval(7200)
        #expect(
            UpdateStateRow.upToDateSentence(checked, now: now)
                == "Up to date · last checked 2 hours ago"
        )
        #expect(UpdateStateRow.upToDateSentence(nil, now: now) == "Up to date")
        #expect(
            UpdateStateRow.notCheckedSentence(checked, now: now)
                == "Last checked 2 hours ago"
        )
        #expect(
            UpdateStateRow.notCheckedSentence(nil, now: now)
                == "Not checked yet"
        )
        // A check a beat AHEAD of the read never says "in 0 seconds".
        for delta in [-2.0, 0.0, 30.0] {
            #expect(
                UpdateStateRow.lastCheckedPhrase(
                    now.addingTimeInterval(-delta),
                    now: now
                ) == "just now",
                Comment(rawValue: "\(delta)")
            )
        }
    }
}
