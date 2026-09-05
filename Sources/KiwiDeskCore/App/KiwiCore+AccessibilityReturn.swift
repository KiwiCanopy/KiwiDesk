import AppKit
import Foundation

/// The accessibility-steal return debt (#958): the window an
/// accessibility system process took activation from, owed a
/// focus back when macOS misdirects the yield.
struct AccessibilityReturnDebt {
    var victim: WindowID
    var at: Date
}

/// The #958 return leg: starting VoiceOver activates
/// `com.apple.universalaccesscontrol`, and when that process
/// yields, macOS re-activates the most recent REGULAR app —
/// KiwiDesk is an accessory app, so its focused own window is
/// skipped in that stack and activation lands on whatever
/// regular app was frontmost before it (device capture
/// 2026-08-27, the yield honored 3.1 s after the panel flag;
/// the issue's original trace shows 3–8 s).
///
/// Core must not refuse the handoff — it is a genuine focus
/// event, and the #952 ruling bans a stand-down that splits
/// state focus from real key focus. So the shape is the #496
/// sibling arm's: keep state focus on the victim and re-assert
/// it with a direct AX raise, which re-activates our own app
/// because AX couples a raise with activation.
///
/// The debt is deliberately narrow, and every let-out clears
/// it:
/// - It arms only when the flagged panel is an accessibility
///   SYSTEM process and the focus anchor is a window of OUR
///   OWN pid — a regular app's focused window is not skipped
///   by the reactivation stack, so no other victim exists.
/// - A report with click provenance is the user choosing;
///   the debt clears without firing.
/// - A report landing back on our own pid fulfils the debt.
/// - Past `accessibilityReturnGrace` the debt expires — a
///   deliberate clickless cross-app focus (VoiceOver
///   navigation, cmd-tab) later than that is never fought.
/// - One shot per steal: the consume clears the debt, so a
///   second steal needs a second panel flag.
/// - A yield landing on a window KiwiDesk raised within
///   `selfRaiseEchoWindow` is our own raise's fallout, not
///   returned — and the debt is left STANDING for the next
///   report, not spent (#887, `AccessibilityReturnTests`).
///
/// The accepted trade: a deliberate clickless focus of another
/// app within the grace of a VoiceOver start is returned once;
/// the next focus event follows normally. `AccessibilityReturnTests`
/// pins the arm, each let-out, and the one-shot.
extension KiwiCore {
    /// How long the debt survives (#958). The misdirected
    /// yield landed 3.1 s after the panel flag on device and
    /// the issue reports 3–8 s, so the bound is sized past the
    /// observed range with margin, while short enough that the
    /// accepted trade above stays rare.
    static let accessibilityReturnGrace: TimeInterval = 12

    /// The bundle ids of the accessibility system processes
    /// whose activation steal this covers. VoiceOver's control
    /// process is the observed one; VoiceOver itself is its
    /// sibling surface.
    static let accessibilityStealBundles: Set<String> = [
        "com.apple.universalaccesscontrol",
        "com.apple.VoiceOver",
    ]

    /// Arms the return debt when an accessibility system
    /// process takes the ignored-panel flag while a window of
    /// our own pid holds the focus anchor. Called beside
    /// `armIgnoredPanel` from the bootstrap wiring.
    func armAccessibilityReturn(bundleID: String?) {
        guard let bundleID,
            Self.accessibilityStealBundles.contains(bundleID),
            let anchor = focusedWindowID,
            let window = state.windows[anchor],
            window.pid
                == pid_t(
                    ProcessInfo.processInfo.processIdentifier
                )
        else { return }
        // A lazy re-report of the same panel must not RENEW
        // the debt: sliding `at` forward stretches the grace
        // past its bound, and each renewal is another chance
        // to fight a deliberate clickless move — the #689
        // semantic-re-arm shape. The first steal's clock
        // stands only while it is LIVE: an expired debt no
        // report ever consumed (the yield landed on an
        // untracked window) is stale, and refusing to replace
        // it would honor every later steal with the same
        // victim (re-review, 2026-08-27). A debt for a
        // DIFFERENT victim is a new steal and replaces it.
        if let debt = accessibilityReturn,
            debt.victim == anchor,
            Date().timeIntervalSince(debt.at)
                < Self.accessibilityReturnGrace
        {
            return
        }
        accessibilityReturn = AccessibilityReturnDebt(
            victim: anchor,
            at: Date()
        )
        onLog(
            "focus: accessibility steal of w\(anchor.raw) "
                + "by \(bundleID); return armed"
        )
    }

    /// The `handleWindowFocused` arm: consumes the debt
    /// against this report and, when the report is the
    /// misdirected yield, keeps state focus on the victim and
    /// re-asserts it with a direct AX raise — the #496 shape,
    /// because reverting state alone would split state focus
    /// from real key focus, and the raise's coupled activation
    /// is what brings the accessory app back. Returns whether
    /// the report was handled (the caller stops there).
    func returnAccessibilitySteal(
        id: WindowID,
        now: Date
    ) -> Bool {
        guard let pid = state.windows[id]?.pid,
            let victim = consumeAccessibilityReturn(
                reportedPid: pid,
                id: id,
                now: now
            )
        else { return false }
        onLog(
            "focus: w\(id.raw) accessibility-steal yield "
                + "returned; re-focusing w\(victim.raw) (#958)"
        )
        if let space = state.workspaces.space(of: victim) {
            state.workspaces.focus(victim, in: space)
        }
        if let window = state.windows[victim],
            let element = eventLoop.element(for: victim)
        {
            AXHelper.raise(element, pid: window.pid)
        }
        updateBorders()
        updateStickyMarks()
        return true
    }

    /// Decides one focus report against the debt: the victim
    /// to re-focus when the report is the misdirected yield,
    /// nil otherwise. Clears the debt on EVERY outcome but
    /// "no debt" — expiry, fulfilment, click, and the consume
    /// itself are all one-shot.
    func consumeAccessibilityReturn(
        reportedPid: pid_t,
        id: WindowID,
        now: Date
    ) -> WindowID? {
        guard let debt = accessibilityReturn else { return nil }
        accessibilityReturn = nil
        let own = pid_t(
            ProcessInfo.processInfo.processIdentifier
        )
        guard
            now.timeIntervalSince(debt.at)
                < Self.accessibilityReturnGrace,
            reportedPid != own,
            !recentClickReached(id, now: now),
            state.windows[debt.victim] != nil
        else { return nil }
        return debt.victim
    }
}
