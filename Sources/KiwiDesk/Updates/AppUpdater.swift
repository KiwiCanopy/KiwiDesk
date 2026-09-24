import Combine
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

    /// What the channel last said (#1536) — an inert updater's
    /// store stays `unavailable`.
    var updates: UpdateStateStore { get }

    /// "What's new" after an update (#1542); nil where the channel
    /// is inert, so an unbundled run owes no notes.
    var whatsNew: WhatsNewCoordinator? { get }

    /// "Install updates automatically" (#1542): Sparkle downloads
    /// in the background and installs when KiwiDesk quits, never
    /// relaunching on its own. Stored by Sparkle, not the profile.
    var autoInstall: AutoInstallSetting { get }
}

/// Live Sparkle update controller (`UpdatePromptFocusTests`, #1011).
@MainActor
final class SparkleUpdater: AppUpdating {
    private let policy: UpdatePromptPolicy
    private let driver: UpdatePromptDriver
    private let updater: SPUUpdater
    let updates = UpdateStateStore()
    private let observer: UpdateCycleObserver
    let whatsNew: WhatsNewCoordinator?
    let autoInstall: AutoInstallSetting

    init() {
        let host = Bundle.main
        policy = UpdatePromptPolicy()
        driver = UpdatePromptDriver(
            hostBundle: host,
            delegate: policy
        )
        observer = UpdateCycleObserver(store: updates)
        observer.onAppcast = { [driver] in driver.loadedItems = $0 }
        observer.onCycleFinished = { [driver] in
            driver.updateCycleFinished()
        }
        updater = SPUUpdater(
            hostBundle: host,
            applicationBundle: host,
            userDriver: driver,
            delegate: observer
        )
        // One record: the window's Install writes what the next
        // launch reads, and the feed is the one Sparkle resolved.
        let record = WhatsNewRecord()
        driver.seenRecord = record
        whatsNew = WhatsNewCoordinator(
            record: record,
            host: host,
            feedURL: { [updater] in updater.feedURL }
        )
        // Sparkle takes the switch only while it checks on its own
        // (`allowsAutomaticUpdates`); both values are KVO.
        autoInstall = AutoInstallSetting(
            read: { [updater] in
                (
                    updater.automaticallyDownloadsUpdates,
                    updater.allowsAutomaticUpdates ? nil : .checksOff
                )
            },
            write: { [updater] in
                updater.automaticallyDownloadsUpdates = $0
            },
            changes: Publishers.Merge(
                updater.publisher(for: \.automaticallyDownloadsUpdates)
                    .map { _ in },
                updater.publisher(for: \.automaticallyChecksForUpdates)
                    .map { _ in }
            )
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        )
        driver.startCheck = { [weak self] in self?.checkForUpdates() }
        do {
            try updater.start()
            // Until this session's first answer only the DATE of
            // the last check is known, never its verdict (#1536).
            updates.set(
                .notChecked(lastChecked: updater.lastUpdateCheckDate)
            )
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
        if updater.canCheckForUpdates {
            updates.set(updates.state.onOwnCheck)
        }
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
    let updates = UpdateStateStore()
    var whatsNew: WhatsNewCoordinator? { nil }
    let autoInstall = AutoInstallSetting.inert()
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
