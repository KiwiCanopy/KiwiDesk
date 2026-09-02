import Foundation

/// The per-Desktop focus memory (#1207): what a Desktop had
/// focused when the user left it, remembered BEFORE the departure
/// fold walks `Space.focused` down the gone windows, and paid back
/// at that window's ARRIVAL on the return — never at the settle,
/// which runs before a slow app re-lists. Keyed like the Space
/// memory (`KiwiCore+DesktopMemory`, #888); every entry point
/// takes the KEY, the way that file's do.
extension KiwiCore {
    /// Records the outgoing Desktop's focused window under `key`.
    /// A nil focus records nothing — an unpaid return must not
    /// overwrite a good entry.
    func rememberDesktopFocus(
        of space: SpaceID,
        leaving desktop: Int,
        key: String
    ) {
        guard let focused = state.workspaces[space]?.focused
        else { return }
        desktopMemory
            .focusedWindows[key, default: [:]][desktop] = focused
    }

    /// Owes the arriving Desktop its remembered focus — only for a
    /// window that is GONE from state: one still present (a
    /// carried sticky, #1145) was never departed and is owed
    /// nothing, so the vacancy rule cannot prefer it.
    func oweDesktopFocus(for desktop: Int, key: String) {
        guard
            let remembered = desktopMemory.focusedWindows[key]?[
                desktop
            ],
            state.windows[remembered] == nil
        else { return }
        desktopMemory.returnFocus.record(remembered)
        onLog(
            "desktop return: owing focus to w\(remembered.raw) "
                + "when Desktop \(desktop) re-lists it"
        )
    }

    /// Pays the debt the fold just honored: the state pick is
    /// made real with the settle's own raise shape (#1207).
    func payReturningFocus(
        arrived window: WindowID,
        effects: AppliedEffects
    ) {
        guard effects.paidReturningFocus,
            desktopMemory.returnFocus.claim(if: { $0 == window })
                != nil
        else { return }
        onLog("desktop return: focus paid to w\(window.raw)")
        focusWindow(window, refocusRetile: false, warp: true)
    }

    /// A native-tab re-key (#308) follows in the memory and the
    /// debt alike, or a returning tab carrier is owed a dead id.
    func rekeyDesktopFocus(old: WindowID, new: WindowID) {
        desktopMemory.returnFocus.rekey(old: old, new: new)
        for (key, entries) in desktopMemory.focusedWindows {
            for (desktop, id) in entries where id == old {
                desktopMemory.focusedWindows[key]?[desktop] = new
            }
        }
    }
}
