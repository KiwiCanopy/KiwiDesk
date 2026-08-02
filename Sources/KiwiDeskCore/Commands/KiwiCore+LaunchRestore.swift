import AppKit
import Foundation

/// The all-minimized arm of Open or Focus (#673).
///
/// `NSRunningApplication.activate()` brings an app forward but
/// does not take anything out of the Dock, so pressing the
/// shortcut for an app whose every window is minimized made the
/// app frontmost with nothing on screen — no visible response at
/// all. The cycle (`cycleToNextWindow`) cannot help: a minimize
/// evicts the window from state entirely.
///
/// The rule, ruled and recorded in `docs/design-decisions.md`:
/// **the shortcut never touches minimized windows while any
/// window is visible; when none are, it restores exactly one, the
/// most recently minimized.** No timer, no in-cycle unminimize —
/// a focus gesture must not undo a parking decision.
extension KiwiCore {
    /// Deminiaturizes one window of `pid` when the app has none
    /// on screen. No-op otherwise, which is the common case, so
    /// the AX walk is paid only on the press that needs it.
    ///
    /// `bundleID` arrives lowercased (the command normalizes it)
    /// and selects the remembered window; the AX list is the
    /// authority on what is actually minimized right now.
    func restoreOneMinimizedIfNothingVisible(
        pid: pid_t,
        bundleID: String
    ) {
        // The same probe `yieldFocusToDesktop` uses, and the same
        // reading: a window on another native desktop is not
        // on-screen either. Restoring locally rather than jumping
        // desktops is the gentler answer — see
        // `docs/accepted-limitations.md`.
        guard
            AXHelper.normalWindowCount(
                pid: pid,
                onScreenOnly: true
            ) == 0
        else { return }
        let minimized = AXHelper.windows(pid: pid)
            .filter(AXHelper.isMinimized)
        guard !minimized.isEmpty else { return }
        // The record is advisory: it is empty for windows
        // minimized before KiwiDesk launched, and its id can be
        // stale. Fall back to the first window in kAXWindows
        // order, which is the app's own front-to-back ordering.
        let remembered = state.lastMinimized(bundleID: bundleID)
        let target =
            remembered.flatMap { id in
                minimized.first {
                    AXHelper.windowID(of: $0) == id
                }
            } ?? minimized[0]
        AXHelper.unminimize(target)
    }
}
