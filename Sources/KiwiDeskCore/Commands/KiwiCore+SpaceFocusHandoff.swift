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
        // Skips a transient overlay (#671, `mayHoldSpaceFocus`):
        // a space whose only member is a popup has nothing to
        // focus, and handing it the slot is what the switch would
        // then ring and raise.
        guard
            let first = space.windows.first(where: {
                state.mayHoldSpaceFocus($0)
            })
        else { return nil }
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
                priorFrontmost: priorFrontmost,
                context: "space settle"
            )
        }
    }

    /// The no-follow move's half of the settle (#482/#483): a
    /// plain `move_to_space` refocuses the origin through the
    /// same cooperative raise a space switch uses, and the OS
    /// may drop it the same way — leaving the MOVED window key
    /// while it sits on another display or stashed offscreen.
    /// The move-intent latch already blocks the focus-follow
    /// teleport; this heals the divergence itself, which
    /// otherwise ALSO makes the #292 preflight silently deny
    /// the next focused command (#483's `_and_follow` "does
    /// nothing"). No frame re-issue — the move's own retile
    /// owns placement; this is focus-only. Guarded like
    /// `scheduleSpaceSettle`: fires only while the origin space
    /// is still active and no native transition is settling,
    /// then delegates the narrow dropped-activate detection to
    /// `reassertSwitchFocus`.
    func scheduleMoveSettle(
        origin: SpaceID?,
        priorFrontmost: pid_t?
    ) {
        deferred.schedule(
            .moveSettle,
            after: .milliseconds(300)
        ) { [weak self] in
            guard let self,
                self.state.workspaces.activeSpace == origin,
                Date().timeIntervalSince(self.lastNativeSwitch)
                    > NativeSwitch.settle
            else { return }
            self.reassertSwitchFocus(
                priorFrontmost: priorFrontmost,
                context: "move settle"
            )
        }
    }

    /// Re-raises the active space's focus anchor when the OS
    /// likely ignored a handoff (#463): the app that was
    /// frontmost BEFORE the triggering command still is, and it
    /// is not the focused window's app. Any other frontmost
    /// means the user (or a later command) moved on — hands off.
    /// Two-caller authority: the space-switch settle (#463,
    /// `priorFrontmost` = frontmost before the switch) and the
    /// no-follow move settle (#482/#483, `priorFrontmost` =
    /// frontmost before the origin refocus raise — the moved
    /// window's app whenever it held focus). The reuse is sound
    /// for a non-obvious reason: detection is pid-granular, and
    /// the #292 preflight divergence the move settle heals is
    /// pid-granular too, so the blind spot and the healed hazard
    /// line up exactly. `context` labels the log with the
    /// triggering settle. Inert until the frontmost seam is
    /// wired (`frontmostPIDProvider`, like the focused-command
    /// guard). The anchor, not `space.focused`: a sticky
    /// traveler legitimately holding cross-space focus must not
    /// be "corrected" back to the local slot (#431). Internal
    /// (not private) for direct guard coverage.
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
    /// - Move-settle edge: a genuine user action inside the
    ///   300 ms that keeps the MOVED window's app frontmost
    ///   (clicking a same-app sibling on the origin) reads as
    ///   "raise never landed" and is re-raised over once — the
    ///   cmd-tab edge's sibling, different signature. Narrowing
    ///   the detection for one caller must keep the other's row
    ///   in view.
    /// - On the Space Bar drag caller (no #292 preflight forcing
    ///   frontmost ≈ focused), `movedHeldFocus` gates arming on
    ///   the RING, so `priorFrontmost` can in principle be an
    ///   unrelated app the user is really in; the guard then
    ///   fires only if that app ALSO stays frontmost through the
    ///   settle — accepted single-shot residue, a decision, not
    ///   an accident.
    func reassertSwitchFocus(
        priorFrontmost: pid_t?,
        context: String
    ) {
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
            "\(context): keyboard focus stayed with pid "
                + "\(frontmost); re-raising window \(focused.raw)"
        )
        focusWindow(focused, refocusRetile: false, warp: false)
    }
}
