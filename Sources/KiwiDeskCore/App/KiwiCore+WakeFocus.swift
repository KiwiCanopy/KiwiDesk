import Foundation

/// The wake/unlock restore's focus payment (#1130). The replay
/// adopts the snapshot's focus, so it must PERFORM that focus —
/// activate and raise, never a bare state stamp — or state and
/// the OS key app diverge and the #292 preflight refuses every
/// shortcut until a click.
extension KiwiCore {
    /// The wake/unlock leg of the restore contract: replay and
    /// settle, then pay the remembered focus for real. The crash
    /// leg keeps `restoreAndSettle` — its startup sweep seeds
    /// focus, and a launch must not steal the OS focus.
    func restoreAndSettleAfterWake(_ snapshot: StateSnapshot) {
        restoreAndSettle(snapshot)
        performWakeFocusPayment()
    }

    /// Pays the adopted focus as a real focus, and arms the
    /// one-shot #292 heal for the case where the app refuses the
    /// activation. `warp: false`: the pointer is wherever the
    /// user unlocked, not ours to move.
    func performWakeFocusPayment() {
        wakeFocusHealArmed = true
        guard let id = focusedWindowID,
            state.windows[id] != nil
        else {
            seedFocusFromFrontmost()
            return
        }
        focusWindow(id, refocusRetile: false, warp: false)
    }

    /// Re-seeds state focus from the OS frontmost — the #442
    /// seed, through the injectable provider — when the
    /// remembered focus is gone, or when the #292 heal fires.
    func seedFocusFromFrontmost() {
        let frontmost = trustedFrontmostProvider?()
            .flatMap { state.windows[$0] != nil ? $0 : nil }
        seedStartupFocus(frontmost: frontmost)
    }

    /// One-shot consume for the #292 preflight: true while the
    /// wake payment awaits its confirming focus event.
    func consumeWakeFocusHeal() -> Bool {
        guard wakeFocusHealArmed else { return false }
        wakeFocusHealArmed = false
        return true
    }

    /// An honored focus event proves state and the OS agree
    /// again — the heal has nothing left to fix.
    func disarmWakeFocusHeal() {
        wakeFocusHealArmed = false
    }
}
