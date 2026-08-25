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
/// What Sparkle's UI must do differently for an app with no Dock
/// tile is one file over, in `UpdatePromptDriver.swift` — a
/// different subject from this one, which is why the seam and its
/// conformers own this file alone.
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

/// The live updater. Held for the process lifetime because
/// Sparkle's scheduled background check has to outlive the call
/// that started it.
///
/// It stores three objects and they are stored for three
/// different reasons, none of them symmetry: `policy` because
/// the driver references its delegate WEAKLY and an unretained
/// one stops being asked; `updater` because it is what
/// `canCheckForUpdates` and `checkForUpdates()` read; `driver`
/// for neither — `SPUUpdater` retains it — but because
/// `UpdatePromptFocusTests` reads the property to hold that the
/// object Sparkle shows its UI through is the overriding one.
@MainActor
final class SparkleUpdater: AppUpdating {
    private let policy: UpdatePromptPolicy
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
    /// **Only construct this behind `make()`.** An unconfigured
    /// host otherwise starts a scheduled network channel that
    /// answers nothing — a bare `.build/release/KiwiDesk`, the
    /// device-QA launch `.claude/rules/tests.md` documents, has
    /// no `Info.plist` and so neither a bundle identifier nor a
    /// feed. Only the first of those makes `start()` refuse
    /// (`checkIfConfiguredProperlyAndRequireFeedURL:NO`, Sparkle
    /// 2.9.6); the feed half of the gate is `make()`'s own
    /// choice, and nothing but that gate would catch it.
    ///
    /// **A refused start is logged and shows nothing, and that
    /// is the ruling rather than an omission.** The standard
    /// controller put up a modal `NSAlert` here — developer-facing
    /// by Sparkle's own description, and from a process with no
    /// Dock tile to explain where it came from, which is the
    /// defect #1011 is. What the user sees instead is the greyed
    /// *Check for Updates…* row, because `canCheckForUpdates`
    /// only turns true inside a successful start. The Config
    /// Issues window is not the channel for it either: that
    /// model's list is REPLACED wholesale by
    /// `KiwiCore.onConfigIssuesChange`, so a GUI-side entry would
    /// be wiped on the next Core update.
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
    /// `UpdaterSeamGuardTests` is the census of the sites this
    /// seam is assembled from, each by exact count, so deleting
    /// the wiring reds as loudly as duplicating it — the start
    /// call included, since a channel that never starts is the
    /// silent half of that pair. Counting is not enough on its
    /// own: `UpdatePromptFocusTests` is what holds that the
    /// driver built here is the one Sparkle is shown through.
    ///
    /// The symmetry is the
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
