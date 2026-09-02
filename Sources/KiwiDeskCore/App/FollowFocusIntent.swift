import Foundation

/// A focus one operation owes a window, paid at that window's
/// ARRIVAL. An intent, not a focus call: macOS attaches focus to
/// a WINDOW, and when the debt is recorded the window sits on an
/// unshown Desktop where AX does not list it. Two instances drain
/// on the one `.windowCreated` arm — `KiwiCore.followFocus`, what
/// `move_to_desktop_and_follow` owes the window it sent away
/// (#1007, `FollowFocusIntentTests`), and
/// `DesktopMemory.returnFocus`, what a Desktop return owes the
/// window the user left focused (#1207) — same drain key (the
/// arriving window), same cardinality (one pending), so nothing
/// was minted. The follow OUTRANKS the return: the verb named its
/// window, so the arrival arm owes no return while a follow
/// stands. Bounded deliberately — an unpaid debt must not fire
/// minutes later. It needs no say in the close-return raise: the
/// #1023 eager fold already stands that down via
/// `EventLoop.eagerDepartureInFlight`. Declared beside
/// `moveLatch` — one verb's bookkeeping answering opposite
/// questions (that one SUPPRESSES an unasked follow, #482/#483;
/// this one OWES an asked one). Before minting a third such
/// ledger (#890's pending no-follow assignment), weigh a third
/// instance — the per-window record, time bound and rekey
/// transfer carry over; the drain key and cardinality may not.
@MainActor
final class FollowFocusIntent {
    /// Maximum duration focus debt remains claimable (5.0s, #1007).
    static let drainWindow: TimeInterval = 5.0

    private var pending: (window: WindowID, at: Date)?

    /// Records that `id` is owed a focus at its arrival.
    func record(_ id: WindowID, at now: Date = Date()) {
        pending = (id, now)
    }

    /// Claims the owed focus if `isPayable` says it can be paid
    /// now (#1007). Three outcomes: paid clears, EXPIRED clears
    /// unpaid, and a live-but-unpayable debt is left standing for
    /// a later drain. The drain runs at the ARRIVAL, deliberately:
    /// a settle is not scoped to the owing window, so an unrelated
    /// switch inside the window would have paid the debt and
    /// yanked focus mid-swipe (review, #1007).
    func claim(
        at now: Date = Date(),
        if isPayable: (WindowID) -> Bool
    ) -> WindowID? {
        guard let window = owed(at: now), isPayable(window)
        else { return nil }
        pending = nil
        return window
    }

    /// The live debt, unpaid: nil once expired (which drops it)
    /// or absent. A READ for the arrival fold's mirror and the
    /// settle's stand-down (#1207); `claim` is the one payer.
    func owed(at now: Date = Date()) -> WindowID? {
        guard let pending else { return nil }
        guard
            now.timeIntervalSince(pending.at) < Self.drainWindow
        else {
            self.pending = nil
            return nil
        }
        return pending.window
    }

    /// Retires the debt unpaid (#1207): a Desktop return owes the
    /// window of THAT return, so the arrival arm forgets the last
    /// return's before deciding whether to owe a new one.
    func forget() {
        pending = nil
    }

    /// Follows a native-tab re-key (#308). Diagnosis is narrated
    /// at the two ends (recorder logs the debt, payer logs the
    /// payment) — a trace carrying the first without the second is
    /// a window that never came back.
    func rekey(old: WindowID, new: WindowID) {
        guard let pending, pending.window == old else { return }
        self.pending = (new, pending.at)
    }
}
