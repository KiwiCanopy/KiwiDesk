import Foundation

/// The wake/unlock restore's focus payment (#1130). The replay
/// adopts the snapshot's focus, so it must PERFORM that focus —
/// activate and raise, never a bare state stamp — or state and
/// the OS key app diverge and the #292 preflight refuses every
/// shortcut until a click. This file is the one machine mutating
/// `wakeFocusHealArmedAt`.
extension KiwiCore {
    /// How long an arm may spend its heal: generous against a
    /// slow unlock, bounded so an ordinary #292 activation race
    /// hours later cannot spend it (an already-key raise never
    /// echoes, so a successful payment often leaves the arm).
    static let wakeFocusHealWindow: TimeInterval = 30

    /// The wake/unlock leg of the restore contract — the crash
    /// leg keeps `restoreAndSettle`, whose settle trio this
    /// inlines: a GONE remembered focus is re-seeded BEFORE the
    /// settle (the #442 launch shape), so the retile and bars
    /// lay out for the focus that stays; a tracked one is paid
    /// as a real focus after it.
    func restoreAndSettleAfterWake(_ snapshot: StateSnapshot) {
        restore(snapshot)
        let remembered = focusedWindowID.flatMap {
            state.windows[$0] != nil ? $0 : nil
        }
        if remembered == nil {
            seedStartupFocus(frontmost: trustedFrontmostTracked())
        }
        spaceSwitchRetile()
        emitSpaceChange()
        if let remembered {
            // `warp: false`: the pointer is wherever the user
            // unlocked, not ours to move.
            focusWindow(remembered, refocusRetile: false, warp: false)
        }
        armWakeFocusHeal()
    }

    /// The one copy of the #442 trusted-frontmost tail: the
    /// injectable provider where wired (nil in unit tests),
    /// the live chain otherwise, filtered to tracked windows.
    /// A blocking AX round trip against an unresponsive app —
    /// callers on a press path pay it at most once per arm.
    func trustedFrontmostTracked() -> WindowID? {
        let raw: WindowID?
        if let provider = trustedFrontmostProvider {
            raw = provider()
        } else {
            raw = trustedFrontmostFocusedWindowID()
        }
        return raw.flatMap { state.windows[$0] != nil ? $0 : nil }
    }

    /// Re-seeds state focus from the OS frontmost when the #292
    /// heal fires. Frontmost arm ONLY — never `seedStartupFocus`'s
    /// guess arm, which could bless a window macOS never reported
    /// focused, the case #292 exists to refuse.
    func reseedFromFrontmostForHeal() -> Bool {
        guard let frontmost = trustedFrontmostTracked() else {
            return false
        }
        seedStartupFocus(frontmost: frontmost)
        return true
    }

    func armWakeFocusHeal() {
        wakeFocusHealArmedAt = Date()
    }

    /// One-shot consume for the #292 preflight: clears the arm
    /// either way, and spends it only inside
    /// `wakeFocusHealWindow` of the payment.
    func consumeWakeFocusHeal(now: Date = Date()) -> Bool {
        guard let armed = wakeFocusHealArmedAt else { return false }
        wakeFocusHealArmedAt = nil
        return now.timeIntervalSince(armed)
            < Self.wakeFocusHealWindow
    }

    /// An honored focus event proves state and the OS agree
    /// again — the heal has nothing left to fix.
    func disarmWakeFocusHeal() {
        wakeFocusHealArmedAt = nil
    }
}
