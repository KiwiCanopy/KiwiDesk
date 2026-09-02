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

    /// Owes the arriving Desktop its remembered focus. The last
    /// return's debt is retired first — a debt lives from one
    /// return to the next, never across a Desktop that owes
    /// nothing — and a standing follow (#1007) outranks it: the
    /// verb named its window. Only a window GONE from state is
    /// owed: one still present (a carried sticky, #1145) never
    /// departed, so the vacancy rule cannot prefer it.
    func oweDesktopFocus(for desktop: Int, key: String) {
        desktopMemory.returnFocus.forget()
        guard
            let remembered = desktopMemory.focusedWindows[key]?[
                desktop
            ],
            state.windows[remembered] == nil
        else { return }
        if let followed = followFocus.owed() {
            onLog(
                "desktop return: w\(remembered.raw) not owed — "
                    + "a follow owes w\(followed.raw)"
            )
            return
        }
        desktopMemory.returnFocus.record(remembered)
        onLog(
            "desktop return: owing focus to w\(remembered.raw) "
                + "when Desktop \(desktop) re-lists it"
        )
    }

    /// Pays the debt at the owed window's arrival. The drain key
    /// is the WINDOW, so its arrival ends the debt either way:
    /// raised with the settle's own shape where the fold honored
    /// it, dropped where the fold declined (a return into a space
    /// that is not active).
    func payReturningFocus(
        arrived window: WindowID,
        effects: AppliedEffects
    ) {
        guard
            desktopMemory.returnFocus.claim(if: { $0 == window })
                != nil
        else { return }
        guard effects.paidReturningFocus else {
            onLog(
                "desktop return: w\(window.raw) arrived unpaid — "
                    + "focus debt dropped"
            )
            return
        }
        onLog("desktop return: focus paid to w\(window.raw)")
        focusWindow(window, refocusRetile: false, warp: true)
    }

    /// The #634 arrangement reset: the memory is id-keyed like
    /// `rememberedSpaces` and goes with it, debt included.
    func forgetDesktopFocus() {
        desktopMemory.focusedWindows = [:]
        desktopMemory.returnFocus.forget()
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
