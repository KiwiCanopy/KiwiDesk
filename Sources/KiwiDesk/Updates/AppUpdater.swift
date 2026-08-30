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

    /// Initiates an update check.
    func checkForUpdates()
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
}

/// Inert updater for tests and unbundled runs.
@MainActor
final class NoUpdater: AppUpdating {
    var canCheckForUpdates: Bool { false }
    func checkForUpdates() {}
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
