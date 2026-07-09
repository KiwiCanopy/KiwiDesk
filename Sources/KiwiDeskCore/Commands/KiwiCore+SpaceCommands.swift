import AppKit
import Foundation

/// Virtual space commands: `focus_space` and
/// `move_to_space(_and_follow)` — the `*_virtual_space` forms are
/// compatibility aliases (#42).
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
            Date().timeIntervalSince(lastNativeSwitch) > 1
        else { return }
        deferred.schedule(
            .focusFollow,
            after: .milliseconds(250)
        ) { [weak self] in
            guard let self else { return }
            guard let window = self.state.windows[id],
                NSWorkspace.shared.frontmostApplication?
                    .processIdentifier == window.pid,
                // An open quick-terminal-style panel makes AX
                // report the app's main window as focused;
                // following that report would enforce the main
                // window's space under the panel the user is
                // actually typing into (issue #21).
                !FloatDetection.hasVisibleIgnoredPanel(
                    pid: window.pid,
                    appName: window.appName
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
            self.state.workspaces.activate(space)
            self.retile(
                animated: self.tiler.settings.animations.onSpaceChange,
                force: true
            )
            self.emitSpaceChange()
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
                appName: app.localizedName ?? "?"
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
        // Hand real (AX) focus to the space's last focused
        // window — otherwise keystrokes keep going to a
        // window that is now stashed offscreen.
        if let next = activeSpace?.focused {
            focusWindow(next, refocusRetile: false)
        }
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
                Date().timeIntervalSince(self.lastNativeSwitch) > 1
            else { return }
            self.retile(
                animated: self.tiler.settings.animations.onSpaceChange,
                force: true
            )
        }
    }

    func moveToSpace(
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        guard let focused = activeSpace?.focused else {
            return .fail("no focused window")
        }
        let target = SpaceID(raw)
        let from = state.workspaces.space(of: focused)
        state.workspaces.add(focused, to: target)
        // The moved window becomes the target space's focus, so
        // the FIRST focus of that space raises it. Without this,
        // `focusSpace` finds no focus to hand over and the window
        // is un-stashed frame-wise but never brought forward —
        // the space renders empty until a later focus event
        // stamps the focus and a second switch surfaces it (#22).
        state.workspaces.focus(focused, in: target)
        if from != target {
            emitWindowMovedToSpace(
                focused,
                app: state.windows[focused]?.appName ?? "",
                from: from,
                to: target
            )
        }
        if follow {
            state.workspaces.activate(target)
            // The retile below owns placement (see focusWindow).
            focusWindow(focused, refocusRetile: false)
            emitSpaceChange()
            // Following is a space switch too: re-assert so the
            // target's other windows survive a dropped frame.
            scheduleSpaceSettle(target)
        } else if let next = activeSpace?.focused {
            // The moved window would keep macOS focus while
            // stashed offscreen; refocus the current space.
            focusWindow(next, refocusRetile: false)
        }
        retile(
            animated: follow
                ? tiler.settings.animations.onSpaceChange : true,
            force: follow
        )
        return .ok()
    }
}
