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
    /// **Only construct this when `make()` says to.** Sparkle's
    /// `-startUpdater` does not fail quietly on a misconfigured
    /// host: it logs, waits a few seconds, and then shows the
    /// user a modal telling them to contact the developer. A bare
    /// `.build/release/KiwiDesk` — the device-QA launch
    /// `.claude/rules/tests.md` documents — has no `Info.plist`
    /// and therefore no bundle identifier, so constructing this
    /// unconditionally puts an "Update Error!" alert on the
    /// screen of an accessory app with no Dock tile to explain
    /// where it came from.
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
    /// `MachineTouchTests` pins both construction sites, by
    /// exact count, so deleting the wiring reds as loudly as
    /// duplicating it — the live channel starting is otherwise
    /// invisible, and an update path that silently never runs is
    /// the one failure `docs/design-decisions.md` ▸ *No
    /// distribution channel without an update path* calls
    /// unrecoverable.
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
