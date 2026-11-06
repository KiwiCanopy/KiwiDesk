import Foundation

/// The Desktop MOVE verbs' bodies — `move_to_desktop` and
/// `move_to_desktop_and_follow` — split from
/// `KiwiCore+DesktopCommands.swift` at the §2.1 ceiling when the
/// #1007 outcome arms joined the follow. By subject: the
/// resolution and the plain switch stay one file over; this file
/// is what a MOVE owes — the cross-screen re-home, the follow's
/// three outcome rulings, and the no-follow bookkeeping.
extension KiwiCore {
    /// `move_to_desktop <n>` / `move_to_desktop_and_follow <n>`
    /// (#25): moves the focused window, or the one a window id
    /// names (#2888), to the Desktop, and with `follow` switches
    /// there after it.
    ///
    /// The move always dispatches: whether the window is already
    /// on that Desktop is not knowable from a target that is
    /// current on ITS screen — the window may sit on another
    /// screen whose current Desktop is a different one — and the
    /// bridge treats a same-Desktop move as the no-op it is.
    /// Only the follow stands down when the screen already shows
    /// the target.
    ///
    /// A Desktop on ANOTHER screen also moves the window's
    /// KiwiDesk-space membership (#1010): the layout is what
    /// carries a window home, so a window left in a space that
    /// lays out on the screen it just left is dragged back
    /// within a second — and macOS then re-assigns its Desktop
    /// to match the frame, undoing the move. The destination is
    /// `StateCoordinator.screenHome`, the same predicate the
    /// arrival path asks on the way back; `docs/design-decisions.md`
    /// carries the ruling.
    ///
    /// A **sticky** window is not refused (`stickyMoveRefused`
    /// gates KiwiDesk-space membership, which a bare Desktop
    /// move does not touch — the re-home above stands down for a
    /// sticky window on exactly that ground): it physically
    /// leaves — and the next Desktop switch carries it back to
    /// wherever the user goes (#1145), which is the promise. An
    /// explicit `space:` IS a membership write, so it takes that
    /// one gate before anything moves (#1150).
    func moveToDesktop(
        _ command: String,
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        switch resolveDesktopArgument(args) {
        case .refused(let response):
            return response
        case .target(let target):
            let window: WindowID
            switch commandTarget(command, args) {
            case .refused(let response):
                return response
            case .window(let id):
                window = id
            }
            if let refusal = desktopMoveRefusal(window) {
                return refusal
            }
            // Read before any filing, which stamps the focus.
            let anchor = focusedWindowID
            let held = window == anchor
            let from = state.workspaces.space(of: window)
            let explicit: SpaceID?
            switch resolveSpaceTarget(args, for: target) {
            case .refused(let response):
                return response
            case .none:
                explicit = nil
            case .space(let space, let landing):
                guard
                    !stickyMoveRefused(
                        window,
                        to: space,
                        landingOn: landing
                    )
                else {
                    return .fail("a sticky window keeps its Space")
                }
                explicit = space
            }
            guard WMBridge.moveWindows([window], to: target.space)
            else {
                return .fail("the Desktop bridge refused the move")
            }
            // An explicit Space outranks the screen-home rule:
            // the user named the destination (#1150).
            if let explicit {
                fileExplicitly(window, in: explicit, target: target)
            } else {
                rehomeAcrossScreens(window, to: target)
            }
            if follow {
                let outcome = switchDesktop(
                    to: target,
                    verb: "move_to_desktop_and_follow"
                )
                switch outcome {
                case .switched:
                    // The one case with a reveal coming: it owes
                    // the window a focus (#1007, recorded before
                    // the fold so the debt exists whatever the
                    // fold's own focus picks do) AND folds the
                    // eager departure (#1023). Narrated at the
                    // RECORD, because the payment narrates too:
                    // a trace showing this line with no "focus
                    // handed to" after it is a window that never
                    // came back, which is otherwise
                    // indistinguishable from the bug this fixes.
                    followFocus.record(window)
                    onLog(
                        "follow: owing focus to w\(window.raw) "
                            + "when its Desktop reveals it"
                    )
                    departEagerly(window)
                case .alreadyShown:
                    // No vanish, no reveal. A window that held
                    // focus keeps key focus through the move
                    // (device-measured 2026-08-25), so only the
                    // state half is owed: the re-home stamps the
                    // destination's focused member without
                    // activating it, and a same-screen follow's
                    // destination is the active Space already.
                    // Anything else has no focus to keep, or a
                    // Space to un-stash, and is a whole switch
                    // (#2888).
                    if let destination =
                        state.workspaces.space(of: window)
                    {
                        if !held
                            || !shownSpaceIDs().contains(destination)
                        {
                            followSwitch(
                                to: destination,
                                focusing: window
                            )
                        } else if destination
                            != state.workspaces.activeSpace
                        {
                            handFollowFocus(
                                to: window,
                                in: destination
                            )
                        }
                    }
                case .refused:
                    // The MOVE already happened — the window
                    // left for the hidden Desktop and only the
                    // switch was refused, so the follow degrades
                    // to a no-follow move and owes exactly its
                    // bookkeeping: the latch, the vanish stamp
                    // and the reap (review round 1 — without
                    // them the departed window's slot lingers
                    // and its key-focus re-report can teleport
                    // the user).
                    departWithoutFollowing(
                        window,
                        held: held,
                        targetIsCurrent: target.isCurrent
                    )
                }
                return outcome.response
            }
            departWithoutFollowing(
                window,
                held: held,
                targetIsCurrent: target.isCurrent
            )
            focusIfFiledIntoActiveSpace(
                window,
                from: from,
                leaving: anchor,
                target: target
            )
            return .ok()
        }
    }

    /// The KiwiDesk-space half of a move onto ANOTHER screen's
    /// Desktop (#1010): the window joins the space that screen
    /// shows, so the retile that follows lays it out where the
    /// user just sent it instead of carrying it home.
    ///
    /// **Only for a Desktop its screen is ALREADY showing**, and
    /// the gate is the whole reason there are two routes rather
    /// than one. That case produces no departure at all, so this
    /// is the only answer there is (device-measured, 2026-08-25:
    /// without it the window snapped back inside 0.6 s, both
    /// directions). A HIDDEN target is the arrival path's, and
    /// answering it here as well is not merely redundant — it is
    /// WRONG: the destination would be the space that screen
    /// shows *now*, while revealing that Desktop can activate a
    /// different one (`handleDesktopChange` restores the
    /// Desktop's remembered Space on the main screen). The
    /// membership would land in a space that is not the one
    /// shown, and — worse — the reap would then remember it on
    /// the arrival's OWN display, standing the create fold's
    /// rule down and leaving the window stashed offscreen in an
    /// invisible space. The arrival resolves when the window
    /// actually lands, against the space really shown then.
    ///
    /// `addFocusedToSpace`, not `moveWindow(_:to:follow:)`: the
    /// verb owns its own focus policy — `departWithoutFollowing`
    /// latches the no-follow hazard and `switchDesktop` the
    /// follow — so the full command's focus hand-off, its origin
    /// re-raise and its #446 yield would fight the one already
    /// chosen.
    ///
    /// It does take that command's OTHER step, and for that
    /// command's own reason (#22, argued at `moveWindow`):
    /// stamping the destination's focus. `workspaces.add` nils
    /// `lastFocused` when the moved window held it and hands the
    /// origin's `focused` to a successor, so without the stamp
    /// the destination surfaces a stale anchor — burying the
    /// window in Monocle, panning it out in Scrolling — and a
    /// session-long nil `lastFocused` reaches every consumer
    /// that reads it. For the window holding focus the stamp is
    /// TRUE rather than a convenience: the gate above means the
    /// window stays visible on the target screen, where it keeps
    /// OS key focus (device-measured, 2026-08-25).
    ///
    /// And it retiles itself. The claim that "each branch
    /// already retiles" is false exactly where this fires: with
    /// `isCurrent` the follow's `switchDesktop` stands down
    /// without switching, so nothing would reflow the
    /// destination screen until an unrelated structural event.
    /// The no-follow reap retiles too, 400 ms later; retiling
    /// here as well places the window at once, which is the
    /// visible half of #1010 (the beat where it sits untiled).
    ///
    /// The display is resolved by matching KiwiDesk's own
    /// displays against the target's UUID through
    /// `NativeSpaces.displayUUID(for:)` — the same seam the
    /// Desktop verbs already name a screen by — so an
    /// unresolvable display simply stands the re-home down.
    private func rehomeAcrossScreens(
        _ window: WindowID,
        to target: DesktopTarget
    ) {
        guard target.isCurrent else { return }
        let from = state.workspaces.space(of: window)
        guard let managed = state.windows[window],
            let display = display(forUUID: target.displayIdentifier),
            let destination = state.screenHome(
                of: managed,
                leaving: from,
                landingOn: display
            )
        else { return }
        onLog(
            "move_to_desktop: crossing screens — homing "
                + "w\(window.raw) to space \(destination.raw)"
        )
        // `from` read BEFORE the move, or subscribers are told
        // the window came from where it just went.
        fileMembership(window, into: destination, from: from)
        retile(animated: true)
    }

    /// The bookkeeping a no-follow Desktop move owes, because no
    /// OS switch follows it to do any of this:
    ///
    /// - The window is gone from every AX list the moment it
    ///   lands, but nothing reaps it — the heal sweep's own doc
    ///   rules itself out for other-Desktop windows — so its
    ///   slot would stay in the layout until some unrelated
    ///   reconcile happened to run. The deferred reconcile below
    ///   is that reap, and the retile closes the hole.
    /// - Stamping the switch window makes the removal classify
    ///   as `vanished` rather than `closed`
    ///   (`WindowGoneReason.classify`) — the window is one
    ///   gesture away, which is exactly what that value means,
    ///   and it is what a swipe's removals report.
    /// - The move latch is the Space twin's #482/#483 guard and
    ///   the hazard is identical: the moved window can keep OS
    ///   key focus, its app re-reports it AX-focused, and the
    ///   focus-follow would flip the user's Space under them.
    /// - The departure record (#1345) keeps the vanish that
    ///   follows a move onto a HIDDEN Desktop as the verb's
    ///   hand-off; a target its screen already shows produces
    ///   no vanish, so nothing is recorded for it. Nor for a
    ///   window that held no focus (#2888): it hands nothing off,
    ///   so its vanish stands the close-return raise down.
    private func departWithoutFollowing(
        _ window: WindowID,
        held: Bool,
        targetIsCurrent: Bool
    ) {
        moveLatch.stamp(window)
        if held {
            recordDesktopMoveDeparture(
                window,
                targetIsCurrent: targetIsCurrent
            )
        }
        lastDesktopSwitch = Date()
        guard let pid = state.windows[window]?.pid else { return }
        // One slot, which a later move re-arms: the pids collect so
        // a burst of named moves reaps every app, not the last.
        desktopMemory.moveReapPIDs.insert(pid)
        deferred.schedule(
            .desktopMoveReap,
            after: .milliseconds(400)
        ) { [weak self] in
            guard let self else { return }
            let pids = self.desktopMemory.moveReapPIDs
            self.desktopMemory.moveReapPIDs = []
            guard self.eventLoop.isRunning else { return }
            for pid in pids {
                self.eventLoop.reconcile(pid: pid, app: AppRef(pid: pid))
            }
            self.retile(animated: true)
        }
    }
}
