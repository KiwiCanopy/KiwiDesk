import Foundation

/// The close-return tail of `handle(_:)` (#913/#929/#935/#936,
/// #1345): whether a removal that lost the focus raises the fold's
/// successor pick, and the track restore that rides the same
/// answer. Split from `KiwiCore+Events.swift` at the §2.1 ceiling;
/// `CloseReturnStandDownWiringTests` scans THIS file.
extension KiwiCore {
    func runCloseReturnTail(
        event: KiwiEvent,
        effects foldEffects: AppliedEffects,
        goneReason: WindowGoneReason?,
        willRetile: Bool
    ) {
        // A close the distrust delayed past a same-app focus on
        // another Space is re-filed as the focus loss it was, owed
        // in its own Space (#2002); every other removal passes
        // through unchanged.
        let facts = healDelayedClose(
            event,
            reason: goneReason,
            effects: foldEffects
        )
        let effects = facts.effects
        let owedSpace = facts.owedSpace
        // Closing or minimizing the focused window hands focus
        // to the space's fallback (state picked one; this raise
        // makes it real). A fallback on a Desktop nobody shows is
        // refused by `focusWindow`'s own gate (#1345). A hide, an
        // active own dialog, a window that left with its Desktop,
        // or a Desktop follow's eager departure stands the raise
        // down —
        // `closeReturnRaiseStandsDown` owns every arm's
        // arguments (#913/#929/#935/#1023). The fold's focus pick
        // still stands: state names the survivor, and the OS's
        // own activation reports it. Guarded on the focus loss
        // so only a removal that would raise pays the seam's
        // NSApplication read.
        let departedWithDesktop =
            departedWithDesktop(event, reason: goneReason)
        if departedWithDesktop, let id = event.goneWindowID {
            fileSwitchDeparture(id)
        }
        let closeReturnRaiseStandsDown =
            effects.removedWindow?.focusLost == true
            && eventLoop.closeReturnRaiseStandsDown(
                after: event,
                departedWithDesktop: departedWithDesktop
            )
        if effects.removedWindow?.focusLost == true,
            !closeReturnRaiseStandsDown,
            let next = owedSpace.map({ state.workspaces[$0]?.focused })
                ?? activeSpace?.focused,
            // Belt to the fold's re-pick (#670): never raise a
            // fullscreen fallback — it would switch the user
            // to its Space on a plain window close.
            state.windows[next]?.isFullscreen != true
        {
            // The owed return's switch, on the raise's branch
            // alone; the switch retile placed the Space, so the
            // focus takes none of its own (#11, #2002).
            if let owedSpace { applyFocusedSpaceSwitch(to: owedSpace) }
            onLog("close-return: raising w\(next.raw)")
            focusWindow(next, refocusRetile: owedSpace == nil, warp: true)
            armCloseReturnRestack(
                to: next,
                fromRemovedSlot: effects.removedWindow?.tiledSlot
            )
        }
        // A structural change in a track space (spawn, close) can
        // push a window into an overflow cascade; fix the pile's
        // z-order once it settles (#193, self-gated on track +
        // actual overflow). AFTER the focus fallback above, so the
        // restore's closing re-focus targets the settled focus,
        // never a stale/nil one (which would clear focus on a
        // minimize). A removal whose return raise stood down
        // arms no restore either (#936): the drain ends in a
        // focus re-raise of the very anchor the stand-down
        // refused — the next mutation's arm heals the pile.
        if willRetile, !closeReturnRaiseStandsDown {
            scheduleTrackZOrderRestoreIfOverflowing()
        }
        // #951/#952 diagnosis: narrate the decision above. AFTER
        // the arms on purpose — the needle windows in
        // `CloseReturnStandDownWiringTests` span the definition
        // and both consulting sites.
        logCloseReturnDecision(
            event: event,
            effects: effects,
            departed: departedWithDesktop,
            standsDown: closeReturnRaiseStandsDown
        )
    }
}
