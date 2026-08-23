import Foundation

/// The ignored-panel dismiss-flag lifecycle (#21/#244/#951):
/// arming on panel focus, the dismiss grace, and the click-
/// provenance escape. Split from `KiwiCore.swift` (350-line
/// ceiling); `handleWindowFocused` in
/// `KiwiCore+FocusEvents.swift` is the one caller.
extension KiwiCore {
    /// How long `ignoredPanelActive` survives a focus report for
    /// another app before being dropped as stale (#951). A live
    /// capture (2026-08-23) measured the dismissed panel app's
    /// stale main-window re-report landing 125-200 ms AFTER the
    /// user's click on another window — clearing the flag
    /// synchronously on that click let the later re-report win
    /// the race and be honored (the focus steal). 1 s is
    /// generous margin over the measured range while short
    /// enough that the accepted trade — a genuine clickless
    /// (cmd-tab) focus of the panel app inside the grace, after
    /// clicking elsewhere, is eaten once — stays rare; the same
    /// class of trade as the documented #465/#496 windows.
    static let ignoredPanelDismissGrace: TimeInterval = 1.0

    /// Flags `pid`'s ignored panel active (#21) and clears any
    /// dismiss grace — a LIVE panel is not in dismissal.
    func armIgnoredPanel(_ pid: pid_t) {
        ignoredPanelActive.insert(pid)
        ignoredPanelDismissDeadline = nil
    }

    /// Arms the same dismiss distrust for KIWIDESK'S OWN pid
    /// (#952): closing the shortcuts summon blip-keys another
    /// own window (Settings) while the app is still active, and
    /// AX re-reports it clickless ~60-110 ms later (capture
    /// 2026-08-23) — AFTER the close's activation yield already
    /// landed, so honoring it moves state focus, ring and warp
    /// onto Settings against the yield. The grace consumes that
    /// handoff report; a genuine click on an own window still
    /// escapes on provenance (#687). Public because the GUI's
    /// panel controller is the caller. The residue is the #292
    /// command guard denying a focused command on an own window
    /// inside the ≤1 s grace — rare, self-clearing, and the
    /// same latch semantics every flagged pid already has.
    public func distrustOwnDismissHandoff() {
        armIgnoredPanel(
            pid_t(ProcessInfo.processInfo.processIdentifier)
        )
    }

    /// Whether the focus report for `id` (its window's pid, if
    /// tracked) is the panel app's stale dismiss re-report and
    /// must be consumed. Mutates the flag/deadline pair for every
    /// outcome — the caller only acts on the return value.
    ///
    /// - The reported pid IS flagged: a report with click
    ///   provenance (#687) is a genuine click escaping distrust —
    ///   clear all flags and return `false`. Otherwise this is
    ///   the dismiss re-report — consume it (`true`), dropping
    ///   only this pid's flag.
    /// - Otherwise, while any flag is set: no deadline yet starts
    ///   the dismissal grace (#951) and keeps the flags; a past
    ///   deadline drops them as stale; inside the grace they are
    ///   kept unchanged. Always returns `false` — a report for a
    ///   different app is never itself consumed.
    func shouldConsumeIgnoredPanelReport(
        pid: pid_t,
        id: WindowID,
        now: Date
    ) -> Bool {
        if ignoredPanelActive.contains(pid) {
            if recentClickReached(id, now: now) {
                onLog(
                    "focus: w\(id.raw) click escapes "
                        + "ignored-panel distrust"
                )
                ignoredPanelActive.removeAll()
                ignoredPanelDismissDeadline = nil
                return false
            }
            ignoredPanelActive.remove(pid)
            if ignoredPanelActive.isEmpty {
                ignoredPanelDismissDeadline = nil
            }
            return true
        }
        guard !ignoredPanelActive.isEmpty else { return false }
        if let deadline = ignoredPanelDismissDeadline {
            if now >= deadline {
                onLog(
                    "focus: w\(id.raw) cleared stale "
                        + "ignored-panel flags "
                        + "\(ignoredPanelActive.sorted())"
                )
                ignoredPanelActive.removeAll()
                ignoredPanelDismissDeadline = nil
            }
        } else {
            ignoredPanelDismissDeadline =
                now + Self.ignoredPanelDismissGrace
            onLog(
                "focus: w\(id.raw) starts ignored-panel "
                    + "dismiss grace "
                    + "\(ignoredPanelActive.sorted())"
            )
        }
        return false
    }
}
