import Foundation

/// The native Desktop verbs (#884, unlocking #25/#26):
/// `focus_desktop`, `move_to_desktop` and
/// `move_to_desktop_and_follow` — the Desktop-side twins of
/// `focus_space` / `move_to_space(_and_follow)`, driven through
/// `WMBridge` on stock macOS with SIP on.
///
/// **A Desktop number is its Mission Control number** — the
/// GLOBAL one, counted across every screen, which is what
/// `bind_profile_to_desktop` already keys on (#888:
/// `DesktopSnapshot.mainDisplayDesktops` documents "a binding
/// keys on that global number"). The verb resolves it in ONE
/// snapshot through `DesktopSnapshot.space(numbered:)`, the
/// inverse of the numbering authority, and then acts on the
/// screen that Desktop lives on — a Desktop has exactly one.
///
/// That is a deliberate REFINEMENT of #890's resolution
/// principle, not a reading of it: the ruling says a number
/// resolves against one screen's list, picking the screen first
/// (moves → the window's screen, switches → the focused
/// screen). Resolving globally instead keeps ONE meaning for
/// "Desktop 3" across bindings, the Profiles card and these
/// verbs; the per-screen reading would give the same number two
/// meanings in one app, which is the defect the Desktop/Space
/// vocabulary ruling exists to remove.
///
/// The device question that decided it, answered 2026-08-25 on
/// two screens with "Displays have separate Spaces" ON: **Mission
/// Control numbers Desktops globally** — the main screen's were
/// labelled 1–2 and the second screen's 3–5, continuing the
/// count rather than restarting it. So the global number IS the
/// number on screen, and a verb, a binding and the Profiles card
/// all name a Desktop the same way. Recorded on #890.
///
/// **Performed is not applied** (os-private-apis.md): the bridge
/// returns nothing a caller can trust. A switch is confirmed by
/// the OS's own notification, which runs `handleDesktopChange`
/// exactly as a swipe does — device-observed 2026-08-25: after
/// `focus_desktop`, the target Desktop's window census replaced
/// the previous one, which only `reconcileAll` on that
/// notification produces. A move has no such signal, so the
/// no-follow path arms its own reap.
extension KiwiCore {
    /// The resolved target of a Desktop verb: the WindowServer
    /// space id and the identifier of the screen it lives on.
    struct DesktopTarget: Equatable {
        let space: SkyLight.SpaceID
        let displayIdentifier: String
        /// Whether the Desktop is already the one its screen
        /// shows — a switch to it is a no-op.
        let isCurrent: Bool
        /// The space that screen shows NOW, from the same
        /// snapshot the target resolved in (#888: one reading,
        /// every question) — the space a switch must hide,
        /// because the pointer write performs no transition of
        /// its own (#1023). Nil when the snapshot cannot say;
        /// equal to `space` exactly when `isCurrent`.
        let originSpace: SkyLight.SpaceID?
    }

    /// Resolves a 1-based Mission Control number against one
    /// topology reading, or nil when no user Desktop has it or
    /// the topology cannot name that Desktop's screen (an
    /// unnamed screen would dispatch an empty identifier and
    /// report success).
    static func desktopTarget(
        number: Int,
        in snapshot: DesktopSnapshot
    ) -> DesktopTarget? {
        guard let space = snapshot.space(numbered: number),
            !space.displayUUID.isEmpty
        else { return nil }
        let origin = snapshot.currentSpaces[space.displayUUID]
        return DesktopTarget(
            space: space.id,
            displayIdentifier: space.displayUUID,
            isCurrent: origin == space.id,
            originSpace: origin
        )
    }

    /// A verb's parse: the target, or the response that refuses.
    private enum DesktopResolution {
        case target(DesktopTarget)
        case refused(CommandResponse)
    }

    /// The parse shared by the three verbs: the capability
    /// first, then the argument. Capability before anything a
    /// caller could get wrong, so a macOS without the bridge
    /// always answers the same refusal rather than reporting
    /// whichever precondition it happened to check first.
    private func resolveDesktopArgument(
        _ args: [JSONValue]
    ) -> DesktopResolution {
        guard canDriveDesktops else {
            return .refused(
                .fail("desktop bridge unavailable on this macOS")
            )
        }
        guard let number = args.first?.intValue, number >= 1 else {
            return .refused(.fail("expected Desktop number (1-based)"))
        }
        guard
            let target = Self.desktopTarget(
                number: number,
                in: NativeSpaces.desktopSnapshot()
            )
        else {
            return .refused(.fail("no Desktop \(number)"))
        }
        return .target(target)
    }

    /// `focus_desktop <n>` (#26): switches the Desktop's screen
    /// to it. The OS notification that follows runs the same
    /// switch handling a swipe does — binding, Space memory,
    /// retile, `desktop_change`.
    func focusDesktop(_ args: [JSONValue]) -> CommandResponse {
        switch resolveDesktopArgument(args) {
        case .refused(let response):
            return response
        case .target(let target):
            return switchDesktop(to: target, verb: "focus_desktop")
        }
    }

    /// `move_to_desktop <n>` / `move_to_desktop_and_follow <n>`
    /// (#25): moves the focused window to the Desktop, and with
    /// `follow` switches there after it.
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
    /// gates KiwiDesk-space membership, which a Desktop move
    /// does not touch — the re-home above stands down for a
    /// sticky window on exactly that ground): it physically
    /// leaves, and its scope keeps meaning "every Space of the
    /// Desktop it is on". Sticky reach ACROSS Desktops is the
    /// collector's own item (#890), unimplemented either way.
    func moveToDesktop(
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        switch resolveDesktopArgument(args) {
        case .refused(let response):
            return response
        case .target(let target):
            guard let focused = focusedWindowID else {
                return .fail("no focused window")
            }
            guard WMBridge.moveWindows([focused], to: target.space)
            else {
                return .fail("the Desktop bridge refused the move")
            }
            rehomeAcrossScreens(focused, to: target)
            if follow {
                return switchDesktop(
                    to: target,
                    verb: "move_to_desktop_and_follow"
                )
            }
            departWithoutFollowing(focused)
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
    /// that reads it. The stamp is TRUE here rather than a
    /// convenience: the gate above means the window stays
    /// visible on the target screen, where it keeps OS key
    /// focus (device-measured, 2026-08-25).
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
        addFocusedToSpace(window, to: destination)
        state.workspaces.focus(window, in: destination)
        // The membership change is a `window_moved_to_space`
        // like any other — `from` read BEFORE the move, or
        // subscribers are told the window came from where it
        // just went.
        emitWindowMovedToSpace(
            window,
            app: managed.appName,
            bundleID: managed.appBundleID,
            from: from,
            to: destination
        )
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
    private func departWithoutFollowing(_ window: WindowID) {
        moveLatch.stamp(window)
        lastDesktopSwitch = Date()
        guard let pid = state.windows[window]?.pid else { return }
        deferred.schedule(
            .desktopMoveReap,
            after: .milliseconds(400)
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning else { return }
            self.eventLoop.reconcile(pid: pid, app: AppRef(pid: pid))
            self.retile(animated: true)
        }
    }
}
