import AppKit
import Foundation

/// Space commands: `move_to_space(_and_follow)` (#42);
/// `focus_space` is `KiwiCore+SpaceSwitch`.
extension KiwiCore {
    /// Follows focus into a hidden window's Space —
    /// but only if that window is still the frontmost app's
    /// AX-focused window after a settle delay. Immediate
    /// following would act on the transient focus re-report
    /// that app activation emits just before a NEW window
    /// opens, dragging the user (and the new window) to the
    /// old window's space.
    func scheduleFocusFollow(_ id: WindowID) {
        // Focus reports during a native desktop transition
        // reference windows that are being re-tracked; they
        // must not flip the Space mid-restore.
        guard
            Date().timeIntervalSince(lastDesktopSwitch)
                > DesktopSwitch.settle,
            // A re-report for a window just moved WITHOUT follow
            // is the dropped origin-refocus raise talking, not
            // the user (#482/#483) — following it would teleport
            // to the space the move explicitly stayed away from.
            !moveLatch.isLatched(id)
        else { return }
        deferred.schedule(
            .focusFollow,
            after: .milliseconds(250)
        ) { [weak self] in
            guard let self else { return }
            guard
                // Re-checked at fire: a no-follow move issued
                // while this follow was pending re-latches.
                !self.moveLatch.isLatched(id),
                let window = self.state.windows[id],
                // Made sticky inside the dwell: following it
                // now would fly the user back (#414) — the
                // schedule-time exemption re-checked at fire.
                !window.isSticky,
                self.frontmostOwns(pid: window.pid),
                // An open quick-terminal-style panel makes AX
                // report the app's main window as focused;
                // following that report would enforce the main
                // window's space under the panel the user is
                // actually typing into (issue #21).
                !self.eventLoop.showsIgnoredPanel(
                    pid: window.pid,
                    bundleID: window.appBundleID,
                    isAccessory: self.eventLoop
                        .classifiesAsOverlay(pid: window.pid)
                ),
                self.eventLoop.focusedWindowID(pid: window.pid) == id,
                let space = self.state.workspaces.space(
                    of: id
                ),
                space != self.state.workspaces.activeSpace
            else { return }
            self.landFocusFollow(id, on: space)
        }
    }

    /// The AX focus-follow's landing on `space`: switch, warp,
    /// and the #412 float raise `focusSpace` and `followSwitch`
    /// pay too (#1727) — on every landing, a Space another
    /// display already shows included, where it is harmless.
    func landFocusFollow(_ id: WindowID, on space: SpaceID) {
        let priorScreen = focusedScreen
        applyFocusedSpaceSwitch(to: space)
        noteDelayedCloseFollowed(id)  // #2002
        // The focus echo that triggered this follow found
        // the window on an inactive space, where the warp
        // guard skips; now that the space is forward the
        // slot frames are real — warp here (#186), handing the
        // pointer over where ⌘Tab crossed screens (#2548).
        warpForSwitch(to: space, focusing: id, leaving: priorScreen)
        raiseLandingFloats(thenFocus: id)
    }

    /// After a restart, land on the Space of the
    /// window the user is focused on right now — the
    /// snapshot's active space is where they were at
    /// shutdown, not where they are. Apps currently showing
    /// an ignored panel are distrusted: while Ghostty's quick
    /// terminal has focus, AX reports the app's *main*
    /// window, which may live on another space (issue #21).
    func activateSpaceOfFocusedWindow() {
        guard
            let id = trustedFrontmostFocusedWindowID(),
            // The cold startup scan may not have tracked the
            // focused window yet — the session snapshot still
            // remembers where it belongs.
            let space = state.workspaces.space(of: id)
                ?? state.rememberedSpace(of: id)
        else { return }
        state.workspaces.activate(space)
    }

    /// The ONE membership filing (#1150): add, the #1708 float
    /// placement or else the #444 re-anchor, the #22 focus stamp,
    /// `window_moved_to_space` —
    /// callers keep their own focus policy and retile. A
    /// same-space re-file is geometry-neutral and emits nothing:
    /// the window may sit on another display than its membership
    /// by USER choice, and placement always wins. `restoring` is
    /// the cross-session pass's (#1385): no focus, no event.
    /// `fileTrade` files a pair through the same `settleFiling`.
    func fileMembership(
        _ window: WindowID,
        into target: SpaceID,
        from: SpaceID?,
        restoring: Bool = false
    ) {
        // Read before the filing: only a window that was no
        // effective float where it left ENTERS floating (#1708).
        let wasFloat = isEffectiveFloatForPlacement(window)
        // Only a window holding the focus, or landing where the
        // user is, moves the trackers; any other is the target's
        // focus for its next visit alone (#22, #1518).
        let takesFocus =
            state.workspaces.lastFocused == window
            || target == state.workspaces.activeSpace
        addFocusedToSpace(window, to: target, restoring: restoring)
        settleFiling(
            window,
            into: target,
            from: from,
            wasFloat: wasFloat,
            takesFocus: restoring ? nil : takesFocus
        )
    }

    /// What a filing owes once the window is in its Space: the
    /// #1708 float placement or else the #444 re-anchor, the #22
    /// focus stamp and `window_moved_to_space`. `takesFocus` nil
    /// is a restore's, which touches no focus and tells no one.
    func settleFiling(
        _ window: WindowID,
        into target: SpaceID,
        from: SpaceID?,
        wasFloat: Bool,
        takesFocus: Bool?
    ) {
        // A target named by an undeclared id takes its screen now:
        // the re-anchor and a follow's Space cue read it (#1994).
        placeUnplacedSpaces()
        if from != target,
            !placeEnteringFloat(window, wasFloat: wasFloat)
        {
            reanchorFloat(window, to: target)
        }
        // A restore's filing touches no focus and tells no one,
        // like the boot replay it completes (#1385).
        guard let takesFocus else { return }
        if takesFocus {
            state.workspaces.focus(window, in: target)
        } else {
            state.workspaces.stampFocus(window, in: target)
        }
        if from != target {
            emitWindowMovedToSpace(
                window,
                app: state.windows[window]?.appName ?? "",
                bundleID: state.windows[window]?.appBundleID,
                from: from,
                to: target
            )
        }
    }

    /// Files a window into a target space honoring that space's
    /// layout: a track-mode target routes through the track
    /// `new_window` rule (#128) so an incoming window opens its
    /// own track (or joins the focused one) and respects the
    /// track cap — the same seam the spawn path uses. A tiled
    /// window into any other mode keeps the historical append,
    /// and a floating window always appends (it has no track
    /// slot). Without this a `move_to_space` into a track space
    /// silently dropped the window into the last track. `after`
    /// places it behind a member outside a track target (a drop).
    /// A user filing seam: every filing not `restoring` stamps
    /// the cross-session match here (#1385), a trade in
    /// `fileTrade`.
    func addFocusedToSpace(
        _ window: WindowID,
        to target: SpaceID,
        after anchor: WindowID? = nil,
        restoring: Bool = false
    ) {
        if !restoring { state.stampUserFiling(window) }
        let floating = state.windows[window]?.isFloating == true
        guard !floating,
            state.workspaces[target]?.mode == .track
        else {
            state.workspaces.add(window, to: target, after: anchor)
            return
        }
        let params = tiler.settings.resolvedTrack(for: target)
        let windows = state.windows
        // A traveler is an explicit placement (#437): it joins the
        // focused track and piles if full — `spillCapacity: nil`
        // suppresses the fill-then-spill, so the move is never
        // second-guessed by relocating the window to a new track.
        state.workspaces.add(
            window,
            to: target,
            trackRule: params.newWindow,
            trackPosition: params.newWindowPosition,
            spillCapacity: nil,
            trackCap: params.trackCap,
            isTiled: { id in
                guard let window = windows[id] else {
                    return false
                }
                // Mirrors the create fold's occupancy (#670):
                // a fullscreen member fills no track slot.
                return !window.isFloating
                    && !window.isFullscreen
            }
        )
    }
}
