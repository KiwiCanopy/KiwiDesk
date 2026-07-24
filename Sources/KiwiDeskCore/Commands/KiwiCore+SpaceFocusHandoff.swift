import AppKit
import Foundation

/// The space-switch keyboard-focus handoff (#463): resolving
/// who focus lands on, yielding to the desktop for an empty
/// target, and the post-switch settle that re-issues dropped
/// frames and re-raises a dropped activate. Split from
/// `KiwiCore+SpaceCommands.swift` (350-line ceiling).
extension KiwiCore {
    /// Who keyboard focus should land on after a switch to the
    /// now-active space: the shared `focusAnchor` (the space's
    /// remembered focus, or a sticky traveler that already holds
    /// the real focus, #416/#431) — else, when the space has
    /// members but no stamped focus, its FIRST member, stamped so
    /// the ring and the raise cannot disagree (#463: a
    /// highlighted window the raise never targeted). Nil only
    /// for a space with nothing to focus. "Resolve", not a pure
    /// query: the fallback path writes the space's focus (and
    /// with it the global `lastFocused`).
    func resolveSpaceSwitchFocusTarget() -> WindowID? {
        guard let space = activeSpace else { return nil }
        if let anchor = state.focusAnchor(of: space) {
            return anchor
        }
        guard let first = space.windows.first else { return nil }
        state.workspaces.focus(first, in: space.id)
        return first
    }

    /// A switch onto a space with nothing to focus leaves the
    /// PREVIOUS space's focused window key while it sits stashed
    /// offscreen — keystrokes keep going to an invisible window
    /// (#463). Hand focus to the desktop instead, the same
    /// orphan cleanup a move-out of the last window uses (#446),
    /// with the same teleport-gated yield behind it.
    ///
    /// Guarded to the exact hazard: `lastFocused` must be a
    /// non-sticky managed window now on a NON-visible space (a
    /// sticky window stays visible somewhere by design, #445),
    /// and — when the frontmost seam is wired — its app must
    /// still be the OS-frontmost one; if the user's real focus
    /// is an unmanaged app, stealing it for Finder would be
    /// worse than the swallowed keys. A visible float/sticky
    /// layer also skips (review): those windows are legitimate
    /// focus recipients, and their in-flight raise-activations
    /// would race the Finder activate — focus settling on a
    /// VISIBLE window never re-creates the #463 hazard.
    func yieldFocusAfterEmptySwitch() {
        guard
            floatLayerTargets().isEmpty,
            let last = state.workspaces.lastFocused,
            let lastSpace = state.workspaces.space(of: last),
            !state.workspaces.visibleSpaces.contains(lastSpace),
            state.windows[last]?.isSticky != true
        else { return }
        if let frontmost = frontmostPIDProvider?(),
            frontmost != state.windows[last]?.pid
        {
            return
        }
        desktopFocusYield?()
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
    /// Besides frames, the settle also verifies the switch's
    /// FOCUS handoff (#463): `AXHelper.raise` ends in a
    /// cooperative `activate()` the OS may quietly drop, leaving
    /// the ring on the target while the previous app keeps key
    /// focus. Detection is deliberately narrow — frontmost app
    /// unchanged since BEFORE the switch yet not the focused
    /// window's app — so a user who moved on to any OTHER app
    /// or window is never fought (edge cases on
    /// `reassertSwitchFocus`).
    /// Single-shot: an app that drops the frame again
    /// on the retry still needs another switch — if that recurs,
    /// re-issue only the windows still at the stash corner rather
    /// than lengthening or repeating this timer.
    func scheduleSpaceSettle(
        _ target: SpaceID,
        priorFrontmost: pid_t?
    ) {
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
            // Deliberately NOT `spaceSwitchRetile()` (#207):
            // the re-issue keeps the instant park so a dropped
            // park lands in one set, not a late visible slide;
            // a still-running exit slide is protected by
            // `stash()`'s in-flight skip.
            self.retile(
                animated: self.tiler.settings
                    .animations.onSpaceChange,
                force: true
            )
            self.reassertSwitchFocus(
                priorFrontmost: priorFrontmost
            )
        }
    }

    /// Re-raises the switch's focus target when the OS likely
    /// ignored the handoff (#463): the app that was frontmost
    /// BEFORE the switch still is, and it is not the focused
    /// window's app. Any other frontmost means the user (or a
    /// later command) moved on — hands off. Inert until the
    /// frontmost seam is wired (`frontmostPIDProvider`, like the
    /// focused-command guard). The anchor, not `space.focused`:
    /// a sticky traveler legitimately holding cross-space focus
    /// must not be "corrected" back to the local slot (#431).
    /// Internal (not private) for direct guard coverage.
    ///
    /// Known edges of the deliberately narrow detection:
    /// - A cmd-tab BACK to the pre-switch app inside the 300 ms
    ///   settle reads as "activate never landed" and is
    ///   re-raised over once (macOS MRU puts exactly that app
    ///   first). Single-shot and recoverable — accepted, see
    ///   the design-decisions limitations row.
    /// - App-granular by choice: a dropped WINDOW raise inside
    ///   an already-frontmost app is invisible here; #463's
    ///   hazard is the dropped app activation.
    /// - A traveler anchor is its own `priorFrontmost`, so a
    ///   float raise stealing frontmost mid-switch reads as
    ///   "moved on" — don't "fix" that into fighting travelers.
    /// - A rapid switch burst keeps only the last capture
    ///   (`.spaceSettle` self-cancels) — single-shot philosophy.
    /// - Unlike the empty-switch yield, this WILL take focus
    ///   from an unmanaged frontmost app: it serves the explicit
    ///   switch command's intent, while the yield's Finder
    ///   target is nobody's intent — asymmetry deliberate.
    func reassertSwitchFocus(priorFrontmost: pid_t?) {
        guard
            let priorFrontmost,
            let frontmost = frontmostPIDProvider?(),
            frontmost == priorFrontmost,
            let space = activeSpace,
            let focused = state.focusAnchor(of: space),
            let pid = state.windows[focused]?.pid,
            pid != frontmost
        else { return }
        onLog(
            "space settle: keyboard focus stayed with pid "
                + "\(frontmost); re-raising window \(focused.raw)"
        )
        focusWindow(focused, refocusRetile: false, warp: false)
    }
}
