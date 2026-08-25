import AppKit
import Foundation
import KiwiDeskCore
import Sparkle
import os

/// The update channel's diagnosis line. `Logger` +
/// `privacy: .public`, never `NSLog` — macOS redacts NSLog
/// content to `<private>` in `log show`, which blinds a capture.
private let updaterLog = Logger(
    subsystem: KiwiLog.subsystem,
    category: "gui"
)

private func logUpdater(_ message: String) {
    updaterLog.log("KiwiDesk: \(message, privacy: .public)")
}

/// KiwiDesk's in-app update channel (#874).
///
/// `docs/design-decisions.md` ▸ *No distribution channel without
/// an update path* is why this exists at all: the gate on a
/// promoted download is Sparkle being IN the build a person
/// installs, and this file is where it gets there.
///
/// **The seam is a protocol because the live implementation
/// reaches the machine.** Constructing `SparkleUpdater` starts a
/// scheduled updater that hits the network and, on an install,
/// spawns Sparkle's XPC services. That is a production default
/// no test may inherit
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

/// Sparkle's stock user driver plus one thing: the prompt that
/// asks to install and restart brings KiwiDesk to the front
/// before it appears (#1011).
///
/// **Why a subclass, when the seam next door is a delegate.**
/// Sparkle activates the app itself for the windows it opens at
/// CHECK time — the update alert, the permission prompt — and
/// `StatusItemController+Updates` activates once more before
/// the check, so the first window a user meets is in front. The
/// install-and-restart prompt is not another window: it is a
/// later state of the status window the DOWNLOAD opened, and
/// Sparkle announces it with `NSApp.requestUserAttention`,
/// which bounces a Dock icon. KiwiDesk has none
/// (`docs/design-decisions.md` ▸ *Permanent accessory mode*),
/// so on the ordinary path — start the download, go back to
/// work while it runs — the app is no longer active when the
/// prompt arrives and the prompt is behind everything the user
/// has open, with nothing saying the update is waiting.
///
/// Neither `SPUUpdaterDelegate` nor
/// `SPUStandardUserDriverDelegate` carries a hook at that
/// moment: the user-driver delegate's alert hooks fire for
/// modal `NSAlert`s, which this is not, and the updater
/// delegate's nearest neighbour (`didExtractUpdate`) fires
/// before the installer has finished preparing. Overriding
/// `showReadyToInstallAndRelaunch` is the only seam that names
/// the moment rather than approximating it.
@MainActor
final class UpdatePromptDriver: SPUStandardUserDriver {
    /// Come forward, then let Sparkle put up the prompt.
    ///
    /// Unconditional rather than gated on `!NSApp.isActive`:
    /// activating an already-active app does nothing, so the
    /// branch would only add a second thing to keep true. Before
    /// `super` rather than after, so the window is already in
    /// front when it turns into the prompt — the order Sparkle's
    /// own activations use.
    override func showReadyToInstallAndRelaunch() async
        -> SPUUserUpdateChoice
    {
        NSApp.activate(ignoringOtherApps: true)
        return await super.showReadyToInstallAndRelaunch()
    }
}

/// The live updater. Owns Sparkle's updater and its user driver
/// for the process lifetime, because Sparkle's scheduled
/// background check needs them to outlive the call that started
/// it.
@MainActor
final class SparkleUpdater: AppUpdating {
    private let driver: UpdatePromptDriver
    private let updater: SPUUpdater

    /// Assembled from `SPUUpdater` and a driver of our own
    /// rather than from `SPUStandardUpdaterController`, which is
    /// those same two objects with the driver fixed to Sparkle's
    /// stock one. #1011 needs that driver overridden, and the
    /// controller exposes no seam for it — it builds the driver
    /// inside its own initializer and offers only the two
    /// delegates, neither of which reaches the moment
    /// `UpdatePromptDriver` overrides.
    ///
    /// The feed URL and the public key both come from
    /// `Info.plist`, which `scripts/build-app.sh` writes, so
    /// there is nothing to configure here and nothing that can
    /// disagree with the shipped bundle.
    ///
    /// **Only construct this when `make()` says to.** Starting
    /// the updater does not fail quietly on a misconfigured
    /// host: it needs a bundle identifier and a feed, and a bare
    /// `.build/release/KiwiDesk` — the device-QA launch
    /// `.claude/rules/tests.md` documents — has no `Info.plist`
    /// and therefore neither. The failure is logged and nothing
    /// is shown, which is where this differs from the standard
    /// controller: that one puts up a modal `NSAlert`, and an
    /// alert from a process with no Dock tile to explain where
    /// it came from is the same defect #1011 is. The alert is
    /// developer-facing by Sparkle's own description, and
    /// `make()`'s gate is what keeps the case off a user's
    /// machine.
    init() {
        let host = Bundle.main
        driver = UpdatePromptDriver(
            hostBundle: host,
            delegate: nil
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

/// The inert stand-in. Reports that it cannot check, so the row
/// that drives it greys itself, and starts no scheduled channel.
@MainActor
final class NoUpdater: AppUpdating {
    var canCheckForUpdates: Bool { false }
    func checkForUpdates() {}
}

/// Chooses the updater this process should use — a flat
/// namespace rather than a protocol extension, because the caller
/// reads `AppUpdaterFactory.make()` and should not have to know
/// which conformer it hangs off (§2.4: keep code flat).
@MainActor
enum AppUpdaterFactory {
    /// The updater this process should use: live when it is a
    /// configured `.app`, inert otherwise.
    ///
    /// **Called exactly once, from `AppDelegate`.** Sparkle's
    /// scheduled check runs for the process lifetime, so a
    /// second instance is a second scheduler against one app —
    /// which is what a future consumer (a Settings section, a
    /// Lua verb) would create by reaching for `SparkleUpdater()`
    /// of its own. It borrows the status item's instead.
    /// `UpdaterSeamGuardTests` pins all four sites — this
    /// factory's call, `SparkleUpdater(` itself, and the
    /// `SPUUpdater` / `UpdatePromptDriver` pair it assembles —
    /// by exact count, so deleting the wiring reds as loudly as
    /// duplicating it. Counting them is not enough on its own:
    /// `UpdatePromptFocusTests` is what holds that the driver
    /// built here is the one Sparkle is shown through. That symmetry is the
    /// point: a missing wiring greys one menu row, which is
    /// visible, while the scheduled channel never starting is
    /// not — and an update path that silently never runs is the
    /// failure `docs/design-decisions.md` ▸ *No distribution
    /// channel without an update path* calls unrecoverable.
    ///
    /// The gate is a property of the BUNDLE rather than of the
    /// build configuration, deliberately — a release binary run
    /// straight out of `.build` is the case that matters, and it
    /// is indistinguishable from the shipped one by
    /// `#if DEBUG`. Both conditions are load-bearing: no bundle
    /// identifier is the bare-binary case, and no `SUFeedURL` is
    /// an `.app` built before the packaging half landed.
    static func make() -> any AppUpdating {
        guard Bundle.main.bundleIdentifier != nil,
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL")
                != nil
        else { return NoUpdater() }
        return SparkleUpdater()
    }
}
