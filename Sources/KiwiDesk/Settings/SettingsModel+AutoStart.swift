import KiwiDeskCore
import SwiftUI

/// The auto-start status, lifted out of `LoginItemCard`'s own
/// `@State` (#678 item 16).
///
/// It lived in the card while ONE control read it. Turn 14b draws
/// two rows in two different containers — the login toggle under
/// "Applies immediately", the crash-restart toggle among
/// Advanced's five — and a second section cannot see another
/// view's `@State`, so the status has to belong to something both
/// can reach.
///
/// Two things follow that are worth stating, because they are the
/// reason this is a lift rather than a copy:
///
/// - **The pair is still folded.** Both rows write through
///   `AutoStartLevel.level(openAtLogin:restartOnCrash:)`, so the
///   contradiction *login off + restart on* cannot be expressed
///   even though two independent-looking toggles now exist.
/// - **The gate becomes answerable.** While the status sat in a
///   view, `.runtime(.loginItemServiceStatus)` could only be
///   resolved inline beside the control, which is what forced it
///   to be declared "resolved elsewhere". Reading it from the
///   model is what lets the area's gate resolver answer it like
///   any other row.
///
/// Read-through is preserved exactly: no cached bool, every
/// mutation re-reads, and `AutoStartManager` keeps doing the
/// blocking launchctl work off the main actor.
extension SettingsModel {
    /// Re-reads the live level. Safe to call repeatedly — the
    /// card calls it on appear and whenever the app reactivates,
    /// because the user may have changed the login item in System
    /// Settings while away.
    /// Skipped while a write is in flight: a `didBecomeActive`
    /// landing mid-write could publish a PRE-write read after the
    /// write's own re-read, transiently showing a stale level.
    /// The write re-reads from OS truth anyway, so nothing is
    /// lost by deferring to the next event.
    func refreshAutoStart() {
        guard !autoStartBusy else { return }
        Task {
            let status = await AutoStartManager.current()
            autoStart = status
            autoStartLoaded = true
        }
    }

    /// Applies a (login, restart) pair.
    ///
    /// The guard is deliberately NOT "is the Advanced row greyed"
    /// — greying is a courtesy to the reader and `gui.md` bans it
    /// as the sole gate on a side effect. `AutoStartLevel.level`
    /// discards the restart flag when login is off, so the
    /// impossible pair collapses before it can reach the OS.
    ///
    /// The unregisterable refusal is the second, independent
    /// defense inherited from #342: on a translocated or bare
    /// binary, applying anything but `.off` would write a
    /// LaunchAgent pointing at an ephemeral path, which
    /// read-through cannot undo.
    func setAutoStart(openAtLogin: Bool, restartOnCrash: Bool) {
        let level = AutoStartLevel.level(
            openAtLogin: openAtLogin,
            restartOnCrash: restartOnCrash
        )
        guard level != autoStart.level else { return }
        guard autoStart.registerable || level == .off else {
            return
        }
        autoStartBusy = true
        Task {
            // Adopt what the OS actually settled on, never the
            // level that was requested — a failed apply re-reads
            // to something else and the rows must say so.
            let result = await AutoStartManager.set(level)
            autoStart = result
            autoStartLoaded = true
            autoStartBusy = false
            flashAutoStart(result.level)
        }
    }

    /// Shows the confirmation for `level` and schedules its fade.
    ///
    /// 2.5 s, longer than the key recorder's 1.5 s
    /// (`KeyRecorderField`) on purpose: that caption is a short
    /// phrase read mid-interaction while the user watches for the
    /// next chord, whereas these are full sentences read once
    /// after a single click, so the reading load is ~double.
    /// Don't "align" it back to 1.5 s.
    private func flashAutoStart(_ level: AutoStartLevel) {
        autoStartFlashToken += 1
        let token = autoStartFlashToken
        withAnimation { autoStartApplied = level }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard autoStartFlashToken == token else { return }
            withAnimation { autoStartApplied = nil }
        }
    }

    /// Whether either row may be driven right now: the first read
    /// has landed, no write is in flight, and this copy can
    /// actually register.
    var autoStartEditable: Bool {
        autoStartLoaded && !autoStartBusy && autoStart.registerable
    }
}
