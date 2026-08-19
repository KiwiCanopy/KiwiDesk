import Foundation
import Sparkle

/// KiwiDesk's in-app update channel (#874).
///
/// `docs/design-decisions.md` ▸ *No distribution channel without
/// an update path* is why this exists at all: the gate on a
/// promoted download is Sparkle being IN the build a person
/// installs, and this file is where it gets there.
///
/// **The seam is a protocol because the live implementation
/// reaches the machine.** Constructing an
/// `SPUStandardUpdaterController` starts a scheduled updater that
/// hits the network and, on an install, spawns Sparkle's XPC
/// services. That is a production default no test may inherit
/// (`.claude/rules/tests.md` ▸ "a test reaches the machine only
/// through a seam it injects"), and the menu builder is
/// constructed by GUI suites that have no business talking to an
/// appcast.
///
/// **The default is inert and that is deliberate, not
/// test-detection.** `NoUpdater` reports it cannot check, so an
/// unwired build greys the row rather than doing something
/// dangerous. The polarity matters: the hotkey seam (#565) has a
/// LIVE default because a forgotten injection there must not
/// silently disable a feature, and the danger is in the live
/// object. Here the danger is also in the live object, but a
/// forgotten injection costs a greyed menu row — visible, inert,
/// and recoverable — so the null object is the safe default and
/// production opts in. `AppDelegate` is the one site that does.
@MainActor
protocol AppUpdating: AnyObject {
    /// Whether an update check can be started right now. Sparkle
    /// says no while a check is already running or an update is
    /// mid-install, and the menu row greys rather than hides —
    /// `.claude/rules/gui.md` ▸ grey, don't hide.
    var canCheckForUpdates: Bool { get }

    /// Begin a user-initiated check. Sparkle owns every piece of
    /// UI from here on, including "you're up to date".
    func checkForUpdates()
}

/// The live updater. Owns the Sparkle controller for the process
/// lifetime, because Sparkle's scheduled background check needs
/// it to outlive the call that started it.
@MainActor
final class SparkleUpdater: AppUpdating {
    private let controller: SPUStandardUpdaterController

    /// `startingUpdater: true` begins the scheduled check cycle
    /// immediately — the feed URL and the public key both come
    /// from `Info.plist`, which `scripts/build-app.sh` writes, so
    /// there is nothing to configure here and nothing that can
    /// disagree with the shipped bundle.
    ///
    /// A build without those keys (a bare `swift build` binary,
    /// which is the documented device-QA launch) simply never
    /// finds a feed. That is why this is constructed from the
    /// `.app` path only.
    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}

/// The inert default. Reports that it cannot check, so the row
/// that drives it greys itself.
@MainActor
final class NoUpdater: AppUpdating {
    var canCheckForUpdates: Bool { false }
    func checkForUpdates() {}
}
