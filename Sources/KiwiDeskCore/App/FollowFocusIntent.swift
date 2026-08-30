import Foundation

/// The focus a `move_to_desktop_and_follow` still owes the window
/// it sent away (#1007, `FollowFocusIntentTests`). An intent, not
/// a focus call: macOS attaches focus to a WINDOW, and at the
/// moment of the move the window sits on an unshown Desktop where
/// AX does not list it. Bounded deliberately — an unpaid debt
/// must not fire minutes later. It needs no say in the
/// close-return raise: the #1023 eager fold already stands that
/// down via `EventLoop.eagerDepartureInFlight`. Declared beside
/// `moveLatch` — one verb's bookkeeping answering opposite
/// questions (that one SUPPRESSES an unasked follow, #482/#483;
/// this one OWES an asked one). Before minting a third such
/// ledger (#890's pending no-follow assignment), weigh extending
/// this — the per-window record, time bound and rekey transfer
/// carry over; the drain key and cardinality do NOT.
@MainActor
final class FollowFocusIntent {
    /// Maximum duration focus debt remains claimable (5.0s, #1007).
    static let drainWindow: TimeInterval = 5.0

    private var pending: (window: WindowID, at: Date)?

    /// Records that `id` was sent to a Desktop the user asked to follow onto.
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

    /// Updates tracked window ID across native tab switches (#308).
    /// Follows a native-tab re-key (#308). Diagnosis is narrated
    /// at the two ends (recorder logs the debt, payer logs the
    /// payment) — a trace carrying the first without the second is
    /// a window that never came back.
    func rekey(old: WindowID, new: WindowID) {
        guard let pending, pending.window == old else { return }
        self.pending = (new, pending.at)
    }
}
