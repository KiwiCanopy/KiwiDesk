import Foundation
import KiwiDeskCore
import Sparkle
import os

/// Diagnostic logger for update subsystem (`KiwiLog.subsystem`).
private let updaterLog = Logger(
    subsystem: KiwiLog.subsystem,
    category: "gui"
)

private func logUpdater(_ message: String) {
    updaterLog.log("KiwiDesk: \(message, privacy: .public)")
}

/// In-app update channel protocol (#874).
@MainActor
protocol AppUpdating: AnyObject {
    /// Whether an update check can be started.
    var canCheckForUpdates: Bool { get }

    /// Initiates an update check — or, while a scheduled update
    /// waits behind a gentle reminder, brings its alert forward
    /// (#1013, Sparkle's documented door).
    func checkForUpdates()

    /// Whether a scheduled update waits behind the gentle reminder
    /// (#1013) — the ONE home of that fact; consumers read it at
    /// render and never keep a copy.
    var updatePending: Bool { get }

    /// Set by the consumer; nudged on the main actor whenever
    /// `updatePending` changes (#1013). Inert updaters never nudge.
    var onUpdatePendingChanged: () -> Void { get set }
}

/// Live Sparkle update controller (`UpdatePromptFocusTests`, #1011).
@MainActor
final class SparkleUpdater: AppUpdating {
    private let policy: UpdatePromptPolicy
    private let driver: UpdatePromptDriver
    private let updater: SPUUpdater

    init() {
        let host = Bundle.main
        policy = UpdatePromptPolicy()
        driver = UpdatePromptDriver(
            hostBundle: host,
            delegate: policy
        )
        updater = SPUUpdater(
            hostBundle: host,
            applicationBundle: host,
            userDriver: driver,
            delegate: nil
        )
        do {
            try updater.start()
        } catch {
            logUpdater(
                "updater failed to start: "
                    + error.localizedDescription
            )
        }
    }

    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    var updatePending: Bool { policy.updatePending }

    var onUpdatePendingChanged: () -> Void {
        get { policy.onUpdatePendingChanged }
        set { policy.onUpdatePendingChanged = newValue }
    }
}

/// Inert updater for tests and unbundled runs. The INERT default
/// is deliberate, not test-detection — the live object starts a
/// network channel and XPC services on construction, so an
/// unwired build greys the row rather than doing something
/// dangerous. Inverted polarity vs the hotkey seam (#565), whose
/// LIVE default exists because a forgotten injection there would
/// silently disable a feature; here it costs a visible grey.
/// tests.md ▸ "one seam runs the OTHER way" owns the two-sided
/// guard this inversion requires (`UpdaterSeamGuardTests`).
@MainActor
final class NoUpdater: AppUpdating {
    var canCheckForUpdates: Bool { false }
    func checkForUpdates() {}
    var updatePending: Bool { false }
    var onUpdatePendingChanged: () -> Void = {}
}

/// Factory resolving active updater implementation (`UpdaterSeamGuardTests`).
@MainActor
enum AppUpdaterFactory {
    /// Returns live updater if bundled with feed URL, else inert updater.
    static func make() -> any AppUpdating {
        guard Bundle.main.bundleIdentifier != nil,
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL")
                != nil
        else { return NoUpdater() }
        return SparkleUpdater()
    }
}
