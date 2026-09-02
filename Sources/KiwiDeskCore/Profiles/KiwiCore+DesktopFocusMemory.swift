import Foundation

/// The returning-focus memory (#1207): each space's last honored
/// focus per Desktop, recorded at the focus REPORT — never at the
/// departure, whose destroys can precede the switch handler
/// (device log 2026-09-02: an app's own AX observer folded its
/// windows before the notification arrived) — and paid back at
/// that window's ARRIVAL on the return, never at the settle,
/// which runs before a slow app re-lists.
extension KiwiCore {
    /// Records an honored focus under the window's space and the
    /// Desktop believed current — stale for a report that beat
    /// the switch handler, which `oweReturningFocus` re-stamps.
    func rememberHonoredFocus(_ id: WindowID) {
        guard let space = state.workspaces.space(of: id)
        else { return }
        desktopMemory.honoredFocus[space, default: [:]][
            lastDesktop ?? 0
        ] = id
        desktopMemory.lastHonored = (id, Date())
    }

    /// Owes the arriving `target` its remembered focus for Desktop
    /// `number`. The last return's debt is retired first — a debt
    /// lives from one return to the next, never across a return
    /// that owes nothing. A focus honored SINCE the previous
    /// switch that is present and focused is macOS's own restore:
    /// it is re-stamped under this Desktop and nothing is owed. A
    /// standing follow (#1007) outranks the memory: the verb named
    /// its window. Only a window GONE from state is owed: a
    /// carried sticky (#1145) never departed and never needs it,
    /// so the vacancy rule cannot prefer it. Reached for EVERY
    /// user-Desktop arrival only because `virtualSpaceTarget`
    /// falls back to the first space (`DesktopFocusMemoryTests` ▸
    /// the unremembered pass-through).
    func oweReturningFocus(
        for target: SpaceID,
        number: Int?,
        since previousSwitch: Date
    ) {
        desktopMemory.returnFocus.forget()
        guard let number else { return }
        if let honored = desktopMemory.lastHonored,
            honored.at > previousSwitch,
            state.windows[honored.window] != nil,
            state.workspaces[target]?.focused == honored.window
        {
            desktopMemory.honoredFocus[target, default: [:]][number] =
                honored.window
            return
        }
        guard
            let remembered = desktopMemory.honoredFocus[target]?[
                number
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
                + "when Desktop \(number) re-lists it"
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
        desktopMemory.honoredFocus = [:]
        desktopMemory.lastHonored = nil
        desktopMemory.returnFocus.forget()
    }

    /// A native-tab re-key (#308) follows in the memory and the
    /// debt alike, or a returning tab carrier is owed a dead id.
    func rekeyDesktopFocus(old: WindowID, new: WindowID) {
        desktopMemory.returnFocus.rekey(old: old, new: new)
        for (space, entries) in desktopMemory.honoredFocus {
            for (desktop, id) in entries where id == old {
                desktopMemory.honoredFocus[space]?[desktop] = new
            }
        }
        if desktopMemory.lastHonored?.window == old {
            desktopMemory.lastHonored?.window = new
        }
    }
}
