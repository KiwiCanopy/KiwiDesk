import AppKit
import Foundation

/// Virtual space commands: `focus_space` and
/// `move_to_space(_and_follow)` (#42).
extension KiwiCore {
    /// Follows focus into a hidden window's virtual space —
    /// but only if that window is still the frontmost app's
    /// AX-focused window after a settle delay. Immediate
    /// following would act on the transient focus re-report
    /// that app activation emits just before a NEW window
    /// opens, dragging the user (and the new window) to the
    /// old window's space.
    func scheduleFocusFollow(_ id: WindowID) {
        // Focus reports during a native desktop transition
        // reference windows that are being re-tracked; they
        // must not flip the virtual space mid-restore.
        guard
            Date().timeIntervalSince(lastNativeSwitch)
                > NativeSwitch.settle
        else { return }
        deferred.schedule(
            .focusFollow,
            after: .milliseconds(250)
        ) { [weak self] in
            guard let self else { return }
            guard let window = self.state.windows[id],
                // Made sticky inside the dwell: following it
                // now would fly the user back (#414) — the
                // schedule-time exemption re-checked at fire.
                !window.isSticky,
                NSWorkspace.shared.frontmostApplication?
                    .processIdentifier == window.pid,
                // An open quick-terminal-style panel makes AX
                // report the app's main window as focused;
                // following that report would enforce the main
                // window's space under the panel the user is
                // actually typing into (issue #21).
                !FloatDetection.hasVisibleIgnoredPanel(
                    pid: window.pid,
                    bundleID: window.appBundleID
                ),
                let element = AXHelper.focusedWindow(
                    pid: window.pid
                ),
                AXHelper.windowID(of: element) == id,
                let space = self.state.workspaces.space(
                    of: id
                ),
                space != self.state.workspaces.activeSpace
            else { return }
            self.applyFocusedSpaceSwitch(to: space)
            // The focus echo that triggered this follow found
            // the window on an inactive space, where the warp
            // guard skips; now that the space is forward the
            // slot frames are real — warp here (#186).
            self.warpMouseToFocused(id)
        }
    }

    /// After a restart, land on the virtual space of the
    /// window the user is focused on right now — the
    /// snapshot's active space is where they were at
    /// shutdown, not where they are. Apps currently showing
    /// an ignored panel are distrusted: while Ghostty's quick
    /// terminal has focus, AX reports the app's *main*
    /// window, which may live on another space (issue #21).
    func activateSpaceOfFocusedWindow() {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            !FloatDetection.hasVisibleIgnoredPanel(
                pid: app.processIdentifier,
                bundleID: AppRef(app).bundleID
            ),
            let element = AXHelper.focusedWindow(
                pid: app.processIdentifier
            ),
            let id = AXHelper.windowID(of: element),
            // The cold startup scan may not have tracked the
            // focused window yet — the session snapshot still
            // remembers where it belongs.
            let space = state.workspaces.space(of: id)
                ?? state.rememberedSpace(of: id)
        else { return }
        state.workspaces.activate(space)
    }

    func focusSpace(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        state.workspaces.activate(SpaceID(raw))
        logSpaceContents(SpaceID(raw))
        retile(
            animated: tiler.settings.animations.onSpaceChange,
            force: true
        )
        // Floats and sticky windows come back above the
        // tiled plane, then real (AX) focus lands on the
        // space's last focused window — otherwise keystrokes
        // keep going to a window that is now stashed
        // offscreen (#412 QA: without the raise, a restored
        // float sat buried behind full-frame tiled windows).
        // Warp at INTENT time: the deferred re-assert runs
        // under the z-order counter, where warps are swallowed
        // — and the forced retile above already assigned the
        // slot the warp targets.
        if let next = activeSpace?.focused {
            warpMouseToFocused(next)
        }
        raiseFloatsAndSticky(thenFocus: activeSpace?.focused)
        emitSpaceChange()
        scheduleSpaceSettle(SpaceID(raw))
        return .ok()
    }

    /// A virtual-space switch applies each window's target frame
    /// exactly once. Slow-AX apps (Electron/WebKit answer lazily)
    /// and deprioritized background windows occasionally drop
    /// that single position update and stay parked offscreen, so
    /// the space comes up missing windows until another switch
    /// re-issues the frames. Re-assert the layout once, shortly
    /// after the switch, so the stragglers land without a manual
    /// second focus. Mirrors `settleAfterNativeSwitch` (#22).
    ///
    /// Layout only — no focus re-assert (unlike the native
    /// settle): a virtual switch already handed real focus to the
    /// space's window, so only dropped *frames* need recovery,
    /// not focus. Single-shot: an app that drops the frame again
    /// on the retry still needs another switch — if that recurs,
    /// re-issue only the windows still at the stash corner rather
    /// than lengthening or repeating this timer.
    func scheduleSpaceSettle(_ target: SpaceID) {
        deferred.schedule(
            .spaceSettle,
            after: .milliseconds(300)
        ) { [weak self] in
            guard let self,
                self.state.workspaces.activeSpace == target,
                // A native desktop switch in this window runs its
                // own retile + settle and is still re-tracking
                // windows; don't collide (cf. scheduleFocusFollow).
                Date().timeIntervalSince(self.lastNativeSwitch)
                    > NativeSwitch.settle
            else { return }
            self.retile(
                animated: self.tiler.settings.animations.onSpaceChange,
                force: true
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
    /// silently dropped the window into the last track.
    func addFocusedToSpace(
        _ window: WindowID,
        to target: SpaceID
    ) {
        let floating = state.windows[window]?.isFloating == true
        guard !floating,
            state.workspaces[target]?.mode == .track
        else {
            state.workspaces.add(window, to: target)
            return
        }
        let params = tiler.settings.resolvedTrack(for: target)
        let windows = state.windows
        state.workspaces.add(
            window,
            to: target,
            trackRule: params.newWindow,
            trackPosition: params.newWindowPosition,
            isTiled: { windows[$0]?.isFloating == false }
        )
    }

    func moveToSpace(
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        guard let focused = focusedWindowID else {
            return .fail("no focused window")
        }
        moveWindow(focused, to: SpaceID(raw), follow: follow)
        return .ok()
    }

    /// Relocates an explicit `window` into `target`. `follow`
    /// switches the visible space to the target; otherwise the
    /// caller's space stays put and the moved window becomes the
    /// target's focus for its next visit. The window-explicit
    /// core behind `move_to_space(_and_follow)` and the Space Bar
    /// drag-drop (#372) — the drag knows the window id, the
    /// command resolves the focused one. When the target is
    /// already the active space (a Space Bar spring drop), this
    /// files the window into the visible layout and focuses it.
    ///
    /// Sticky moves are guarded up front via `stickyMoveRefused`
    /// (#445) — the same gate the Space-Bar spring calls, since
    /// `addFocusedToSpace` (not `moveWindow`) is the real re-home
    /// choke point and has two callers.
    func moveWindow(
        _ window: WindowID,
        to target: SpaceID,
        follow: Bool
    ) {
        let from = state.workspaces.space(of: window)
        if stickyMoveRefused(window, to: target) { return }
        // Captured before the focus reassign below overwrites it:
        // whether the moved window currently holds OS key focus.
        // Only then must an emptied origin yield focus (#446).
        let movedHeldFocus = state.workspaces.lastFocused == window
        addFocusedToSpace(window, to: target)
        // The moved window becomes the target space's focus, so
        // the FIRST focus of that space raises it. Without this,
        // `focusSpace` finds no focus to hand over and the window
        // is un-stashed frame-wise but never brought forward —
        // the space renders empty until a later focus event
        // stamps the focus and a second switch surfaces it (#22).
        state.workspaces.focus(window, in: target)
        if from != target {
            emitWindowMovedToSpace(
                window,
                app: state.windows[window]?.appName ?? "",
                bundleID: state.windows[window]?.appBundleID,
                from: from,
                to: target
            )
        }
        if follow {
            state.workspaces.activate(target)
            // The retile below owns placement (see focusWindow).
            focusWindow(window, refocusRetile: false, warp: true)
            emitSpaceChange()
            // Following is a space switch too: re-assert so the
            // target's other windows survive a dropped frame.
            scheduleSpaceSettle(target)
        } else if let next = activeSpace?.focused {
            // The moved window would keep macOS focus while
            // stashed offscreen; refocus the current space.
            focusWindow(next, refocusRetile: false, warp: true)
        } else if movedHeldFocus,
            from == state.workspaces.activeSpace
        {
            // The moved window was the ONLY one on the focused
            // display's space, so there is no neighbor to refocus
            // and it would keep key focus offscreen. Hand focus to
            // the desktop — the same state a bare empty-desktop
            // click leaves (#446). Scoped to the active space: a
            // Space-Bar drag from a *non-active* space (the other
            // `moveWindow` caller) leaves the user's focus alone.
            desktopFocusYield?()
        }
        retile(
            animated: follow
                ? tiler.settings.animations.onSpaceChange : true,
            force: follow
        )
    }
}
