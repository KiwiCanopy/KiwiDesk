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

    /// The Settings switch's setter: the LOGIN ITEM only
    /// (#1071). Crash supervision is the CLI's, and this path
    /// reaches no `ServiceManager` call, so a click taken on a
    /// stale status cannot unload a service the user started
    /// from a terminal.
    ///
    /// The registerability refusal is the same one
    /// `setAutoStart` carries, and for the same #342 reason: a
    /// translocated or bare copy would register a login item
    /// pointing at an ephemeral path, which read-through cannot
    /// undo. It lives here rather than in the view because the
    /// harm is a filesystem side effect.
    func setLoginItem(_ enabled: Bool, reduceMotion: Bool) {
        // The service owns the answer while it is loaded, so
        // the model refuses here and not only in the view — a
        // grey is never the sole gate on a side effect, and
        // this one writes an OS registration (gui.md). Found by
        // `greyAndRefusalAgree` once it read the real setter
        // instead of a copy of the resolver's predicate.
        guard autoStart.level != .atLoginWithAutoRestart else {
            return
        }
        guard enabled != autoStart.level.opensAtLogin else {
            return
        }
        guard autoStart.registerable || !enabled else { return }
        autoStartBusy = true
        Task {
            let result = await AutoStartManager.setLoginItem(
                enabled
            )
            autoStart = result
            autoStartLoaded = true
            autoStartBusy = false
            flashAutoStart(
                result.level,
                reduceMotion: reduceMotion
            )
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
    ///
    /// `reduceMotion` comes from the caller's environment, the
    /// same way `flipSettingsMode` takes it — a model has no
    /// environment of its own to read. With it on the caption
    /// appears and leaves without the cross-fade: the house
    /// split keeps the affordance and drops only the motion,
    /// and the confirmation IS the affordance here (nothing
    /// else says the level applied).
    private func flashAutoStart(
        _ level: AutoStartLevel,
        reduceMotion: Bool
    ) {
        autoStartFlashToken += 1
        let token = autoStartFlashToken
        let fade: Animation? = reduceMotion ? nil : .default
        withAnimation(fade) { autoStartApplied = level }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard autoStartFlashToken == token else { return }
            withAnimation(fade) { autoStartApplied = nil }
        }
    }

    /// A transient block that is NOT a gate reason: the first read
    /// has not landed, or a write is in flight. The rows grey while
    /// it holds, but there is no sentence — nothing is wrong, the
    /// live value is simply not known yet.
    var autoStartLoading: Bool {
        !autoStartLoaded || autoStartBusy
    }

    /// The area's gate resolver over the live status. The rows
    /// consult THIS for their durable greying and its sentence,
    /// rather than re-deriving each predicate inline — the same
    /// shape `LayoutCard` takes with `LayoutDefaultsGates`, so the
    /// census-declared owner and the on-screen grey cannot drift.
    var generalGates: GeneralGates {
        GeneralGates(autoStart: autoStart)
    }
}
