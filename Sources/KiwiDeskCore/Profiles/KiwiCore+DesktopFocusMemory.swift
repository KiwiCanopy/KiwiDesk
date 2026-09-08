import Foundation

/// The returning-focus memory (#1207): each space's last honored
/// focus, recorded at the focus REPORT under the native Space the
/// WindowServer hosts the window on, and paid back at that
/// window's ARRIVAL on the return. The argument is
/// state-and-layout.md's.
extension KiwiCore {
    /// Records an honored focus under the window's space and the
    /// native Space it is on — the compositor's answer, so a report
    /// that beats the switch handler lands under the right key.
    func rememberHonoredFocus(_ id: WindowID) {
        guard let space = state.workspaces.space(of: id) else { return }
        // A focus honored in the active space while a return's
        // debt stands is the user's or the OS's own choice: the
        // memory yields, or the owed window's arrival pays over
        // it (CI, 2026-09-02). The payment claims BEFORE it
        // raises, so its own echo finds nothing to retire.
        if let owed = desktopMemory.returnFocus.owed(),
            space == state.workspaces.activeSpace
        {
            desktopMemory.returnFocus.forget()
            onLog(
                "desktop return: debt to w\(owed.raw) retired — "
                    + "focus honored on w\(id.raw)"
            )
        }
        guard let native = hostedNativeSpace(of: id) else { return }
        desktopMemory.honoredFocus[space, default: [:]][native] = id
    }

    /// The memory's key: the native Space the compositor hosts
    /// `id` on, through the one door (#1146, the seam
    /// `DesktopCensusSeamTests` pins) — the write and the
    /// remembered-focus read derive it here alone, so the two
    /// cannot key differently.
    private func hostedNativeSpace(of id: WindowID) -> SkyLight.SpaceID? {
        guard case .hosted(let native) = desktopMemory.readWindowSpace(id)
        else { return nil }
        return native
    }

    /// Owes the arriving `target` the focus last honored on
    /// `native`, the Desktop being shown. The last return's debt
    /// is retired first — a debt lives from one return to the
    /// next. A standing follow (#1007) outranks the memory. Only a
    /// window GONE from state is owed: a carried sticky (#1145) or
    /// a window macOS restored and KiwiDesk already honored is
    /// present and needs nothing. Reached for EVERY user-Desktop
    /// arrival only because `virtualSpaceTarget` falls back to the
    /// first space (`DesktopFocusMemoryTests` ▸ the unremembered
    /// pass-through).
    func oweReturningFocus(
        for target: SpaceID,
        native: SkyLight.SpaceID?
    ) {
        desktopMemory.returnFocus.forget()
        guard let native,
            let remembered = desktopMemory.honoredFocus[target]?[
                native
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
                + "when space \(target.raw) re-lists it"
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

    /// How fresh a return must be for its focus report to read as
    /// macOS restoring it: the restore lands within ~150 ms of
    /// the arrival on device, the #1161 bounce no sooner than
    /// 0.8 s after a placement.
    static let restoredFocusWindow: TimeInterval = 0.5

    /// Whether a report for `id` is macOS restoring this
    /// Desktop's focus (#1345): the window RETURNED within
    /// `restoredFocusWindow` and is the memory's entry under the
    /// compositor's host. The placement distrust (#1161) stands
    /// down on it; the trade is docs/design-decisions.md's.
    func isRestoredDesktopFocus(_ id: WindowID, now: Date) -> Bool {
        guard let returned = recentReturns[id],
            now.timeIntervalSince(returned) < Self.restoredFocusWindow,
            let space = state.workspaces.space(of: id),
            let native = hostedNativeSpace(of: id)
        else { return false }
        return desktopMemory.honoredFocus[space]?[native] == id
    }

    /// The #634 arrangement reset: the memory is id-keyed like
    /// `rememberedSpaces` and goes with it, debt included.
    func forgetDesktopFocus() {
        desktopMemory.honoredFocus = [:]
        desktopMemory.returnFocus.forget()
    }

    /// A window closed while away (#1146) leaves the memory too,
    /// or the next return owes a debt to a window that is gone.
    func retireDesktopFocus(of id: WindowID) {
        for (space, entries) in desktopMemory.honoredFocus {
            for (native, owed) in entries where owed == id {
                desktopMemory.honoredFocus[space]?[native] = nil
            }
        }
    }

    /// A native-tab re-key (#308) follows in the memory and the
    /// debt alike, or a returning tab carrier is owed a dead id.
    func rekeyDesktopFocus(old: WindowID, new: WindowID) {
        desktopMemory.returnFocus.rekey(old: old, new: new)
        for (space, entries) in desktopMemory.honoredFocus {
            for (native, id) in entries where id == old {
                desktopMemory.honoredFocus[space]?[native] = new
            }
        }
    }
}
