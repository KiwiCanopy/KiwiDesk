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
/// vocabulary ruling exists to remove. Recorded on #890 for the
/// owner to overturn; the open device question is whether
/// Mission Control labels Desktops per screen with "Displays
/// have separate Spaces" on, which no probe has answered.
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
        return DesktopTarget(
            space: space.id,
            displayIdentifier: space.displayUUID,
            isCurrent: snapshot.currentSpaces[space.displayUUID]
                == space.id
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
    /// A **sticky** window is not refused (`stickyMoveRefused`
    /// gates KiwiDesk-space membership, which a Desktop move
    /// does not touch): it physically leaves, and its scope
    /// keeps meaning "every Space of the Desktop it is on".
    /// Sticky reach ACROSS Desktops is the collector's own item
    /// (#890), unimplemented either way.
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

    /// The one copy of the switch dispatch, for both verbs that
    /// switch. Stamps the switch at INTENT time — but only once
    /// the bridge has accepted it, so a refusal does not
    /// suppress a second of focus-follow that no switch earned.
    private func switchDesktop(
        to target: DesktopTarget,
        verb: String
    ) -> CommandResponse {
        guard !target.isCurrent else { return .ok() }
        guard
            WMBridge.setCurrentSpace(
                target.space,
                displayIdentifier: target.displayIdentifier
            )
        else {
            onLog("\(verb): the Desktop bridge refused the switch")
            return .fail("the Desktop bridge refused the switch")
        }
        lastDesktopSwitch = Date()
        return .ok()
    }
}
