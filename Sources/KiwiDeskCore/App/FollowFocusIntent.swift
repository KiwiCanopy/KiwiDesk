import Foundation

/// The focus a `move_to_desktop_and_follow` still owes the window
/// it sent away (#1007).
///
/// **Why an intent rather than a focus call.** macOS attaches
/// keyboard focus to a WINDOW, never to a screen, so switching
/// another screen's Desktop is the whole of what the switch can
/// do. At the moment of the move the window is not addressable —
/// it sits on a Desktop nobody is showing, so Accessibility does
/// not list it — and focusing it has to wait until the reveal
/// makes it real. This records that debt.
///
/// **Bounded rather than open-ended, deliberately.** A follow
/// macOS declined — or one whose Desktop the user never returns
/// to — must not fire minutes later and yank focus to a window
/// they have forgotten about.
///
/// The record needs no say in the close-return raise: the
/// departure it describes is the #1023 eager fold, which is
/// synchronous and already stands that raise down through the
/// stand-down predicate's own arm
/// (`EventLoop.eagerDepartureInFlight`) — no other removal of
/// the followed window can reach the fold, because the fold
/// also releases the event loop's registration.
///
/// Not an actor and not `Sendable`: it is `@MainActor` state on
/// `KiwiCore`, declared beside `moveLatch` — the two halves of
/// one verb's bookkeeping answering opposite questions. That one
/// suppresses a focus-follow the user did not ask for
/// (#482/#483, the no-follow move); this one owes a focus they
/// did.
///
/// **A third per-window, time-bounded, re-key-following ledger
/// is already planned** — #890's pending assignment for the
/// no-follow Desktop move, which records "window W belongs to
/// space S of Desktop D" and drains when D is shown. If that
/// lands, extend this rather than minting a third beside it: the
/// shape is identical and only the payload differs.
@MainActor
final class FollowFocusIntent {
    /// How long the focus debt stays claimable: long enough for
    /// the switch and for the window's app to re-list it on the
    /// revealed Desktop, with room for a slow app. Past it the
    /// reveal did not happen and the intent is abandoned, so a
    /// follow macOS declined cannot fire minutes later.
    ///
    /// A slack bound rather than a derived one — nothing in the
    /// tree measures how long an app takes to answer AX after a
    /// reveal. Read `FollowFocusIntentTests`' green as holding
    /// the behavior around the bound, never its magnitude.
    static let drainWindow: TimeInterval = 5.0

    private var pending: (window: WindowID, at: Date)?

    /// Record that `id` was deliberately sent to a Desktop the
    /// user asked to follow it onto.
    func record(_ id: WindowID, at now: Date = Date()) {
        pending = (id, now)
    }

    /// Take the owed focus, if one is still owed and
    /// `isPayable` says it can be paid now.
    ///
    /// **Three outcomes, and the middle one is the reason this
    /// takes a predicate at all.** A debt that pays is cleared,
    /// because a debt is paid once. An EXPIRED debt is cleared
    /// unpaid. A live debt the caller cannot pay yet — the
    /// window is back on screen but its app has not relisted it
    /// — is left standing, so a later drain can still pay it
    /// rather than the first drain swallowing it.
    ///
    /// **The unpayable case is rare by construction**, because
    /// the drain runs at the ARRIVAL — the moment the window
    /// re-materializes on the revealed Desktop, which is the
    /// definition of it being addressable again. An earlier draft
    /// drained at the reveal SETTLE instead and had to reason
    /// about being too early; worse, a settle is not scoped to
    /// the window that owes, so an unrelated switch inside
    /// `drainWindow` would have paid the debt and yanked focus
    /// mid-swipe (review, #1007).
    func claim(
        at now: Date = Date(),
        if isPayable: (WindowID) -> Bool
    ) -> WindowID? {
        guard let pending else { return nil }
        guard
            now.timeIntervalSince(pending.at) < Self.drainWindow
        else {
            self.pending = nil
            return nil
        }
        guard isPayable(pending.window) else { return nil }
        self.pending = nil
        return pending.window
    }

    /// Follow a native-tab re-key (#308), so a window that
    /// changed id mid-flight is still the one we owe focus to.
    func rekey(old: WindowID, new: WindowID) {
        guard let pending, pending.window == old else { return }
        self.pending = (new, pending.at)
    }

    /// Diagnosis is narrated at the two ends rather than read
    /// out of here: the recorder logs the debt and the payer
    /// logs the payment, so a trace carrying the first without
    /// the second is a window that never came back — a symptom
    /// otherwise indistinguishable from the bug being fixed, on
    /// a subsystem whose only channel is `log stream`.
}
