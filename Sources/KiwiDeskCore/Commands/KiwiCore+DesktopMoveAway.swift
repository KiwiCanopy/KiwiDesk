import Foundation

/// A Desktop move naming a window on a hidden Desktop (#3034). The
/// window is in the away ledger, never in state, so no departure
/// follows the move: its filing is written at once, and the arrival's
/// ordinary rule pays it.
extension KiwiCore {
    /// Moves `away` to `target`, and with `follow` switches there.
    func moveAwayToDesktop(
        _ away: AwayWindow,
        to target: DesktopTarget,
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        // A stale ledger would pass a follow no arrival can pay.
        refreshAwayHosts()
        let away = state.awayWindows[away.id] ?? away
        if let refusal = awayMoveRefusal(away, to: target, follow: follow) {
            return refusal
        }
        let explicit: SpaceID?
        var crossingBase: CGRect?
        switch resolveSpaceTarget(args, for: target, moving: away.id) {
        case .refused(let response):
            return response
        case .none:
            explicit = nil
        case .space(let space, let landing):
            guard !awayIsSticky(away) else {
                return .fail("a sticky window keeps its Space")
            }
            explicit = space
            crossingBase = landing.flatMap {
                crossesScreens(away.id, to: $0, target)
                    ? crossingBaseOfAway(away.id) : nil
            }
        }
        // Any move of a window whose crossing is landing, or that
        // landing would undo it.
        guard !desktopMemory.crossingsInFlight.contains(away.id) else {
            return .fail("A window moves again once its last move lands.")
        }
        guard let crossingBase, let explicit else {
            return landAway(away, to: target, explicit, follow: follow)
        }
        desktopMemory.crossingsInFlight.insert(away.id)
        // The frame lands first: moved first, the window shows on its
        // old screen (#3048). So the answer is the parse's: a write
        // that finds the element naming another window, or a bridge
        // that refuses later, only logs.
        writeCrossingFrame(away.id, from: crossingBase, to: explicit) {
            [weak self] wrote in
            guard let self else { return }
            self.desktopMemory.crossingsInFlight.remove(away.id)
            // Up to the deadline later: the window may have arrived,
            // gone or changed since the parse. The follow's switch
            // needs no dispatch scope: the OS's own switch notification
            // runs the handling, as it does for a swipe.
            guard wrote, let now = self.state.awayWindows[away.id],
                self.awayMoveRefusal(now, to: target, follow: follow)
                    == nil
            else {
                self.onLog(
                    "move_to_desktop: w\(away.id.raw) not moved — its "
                        + "frame could not be written, or it changed"
                )
                return
            }
            let landed = self.landAway(
                now,
                to: target,
                explicit,
                follow: follow
            )
            if let error = landed.error {
                self.onLog("move_to_desktop: w\(away.id.raw) — \(error)")
            }
        }
        guard follow else { return .ok() }
        let outcome: DesktopSwitchOutcome =
            target.isCurrent ? .alreadyShown : .switched
        return outcome.response
    }

    /// The move itself, its filing and what the verb owes after it.
    private func landAway(
        _ away: AwayWindow,
        to target: DesktopTarget,
        _ explicit: SpaceID?,
        follow: Bool
    ) -> CommandResponse {
        guard WMBridge.moveWindows([away.id], to: target.space) else {
            return .fail("the Desktop bridge is unavailable on this macOS")
        }
        if let explicit { state.workspaces.ensureSpace(explicit) }
        // Arriving now, an unfiled window takes the Space its screen
        // shows, or the fold would grant it a new window's focus. A
        // hidden Desktop's reveal decides that Space itself (#1010).
        state.fileAwayMove(
            away.id,
            named: explicit,
            home: target.isCurrent
                ? moveHereSpace(on: screenHolding(away.id)) : nil
        )
        onLog(
            "move_to_desktop: away w\(away.id.raw) filed under space "
                + "\(state.rememberedSpace(of: away.id)?.raw ?? "none")"
        )
        guard follow else {
            armMoveReap(pid: away.pid)
            oweFocusIfVacant(away.id, to: target)
            return .ok()
        }
        let outcome = switchDesktop(
            to: target,
            verb: "move_to_desktop_and_follow"
        )
        switch outcome {
        case .switched:
            followFocus.record(away.id)
            onLog(
                "follow: owing focus to w\(away.id.raw) "
                    + "when its Desktop reveals it"
            )
        case .alreadyShown:
            // No reveal: the Space switches now and the reap's
            // arrival takes a plain focus, as Move here's does.
            armMoveReap(pid: away.pid)
            if let space = shownFollowSpace(of: away.id, on: target) {
                enterMoveHereSpace(space)
                jump.owe(
                    away.id,
                    in: space,
                    at: wallClock(),
                    relocates: true,
                    hopped: true
                )
            }
        case .refused:
            armMoveReap(pid: away.pid)
        }
        return outcome.response
    }

    /// A window arriving in the active Space where nothing holds the
    /// focus takes it from the fold in state alone, which would fail
    /// the next focused verb's #292 preflight, so it owes the raise.
    /// It owes no filing: a landing the #1010 net re-homes stands down.
    private func oweFocusIfVacant(
        _ window: WindowID,
        to target: DesktopTarget
    ) {
        guard target.isCurrent,
            let active = state.workspaces.activeSpace,
            state.rememberedSpace(of: window) == active,
            state.workspaces[active]?.focused == nil
        else { return }
        jump.owe(
            window,
            in: active,
            at: wallClock(),
            relocates: false
        )
    }

    /// What refuses an away window before anything moves. A follow
    /// ends with focus on the window, which a minimized or hidden one
    /// cannot take, so it never switches for one.
    private func awayMoveRefusal(
        _ away: AwayWindow,
        to target: DesktopTarget,
        follow: Bool
    ) -> CommandResponse? {
        switch state.pocketPhase(of: away.id) {
        case .pocketed:
            return .fail(Self.pocketedMoveRefusal)
        case .out:
            return .fail(Self.outPocketMoveRefusal)
        case nil:
            break
        }
        if isFullScreenHost(away.nativeSpace, in: target.spaces) {
            return .fail("a full-screen window cannot change Desktop")
        }
        if follow, !away.isUp {
            return .fail("Can't follow a minimized or hidden window.")
        }
        return nil
    }

    /// Whether `away` left with a sticky scope, restored at its
    /// arrival (#414). A named Space is a membership write, and the
    /// sticky gate reads tracked windows, so every scope refuses here,
    /// a screen-sticky window's other-screen re-home included.
    private func awayIsSticky(_ away: AwayWindow) -> Bool {
        let window = ManagedWindow(
            id: away.id,
            pid: away.pid,
            appName: away.appName,
            appBundleID: away.appBundleID,
            title: away.title
        )
        return state.remembersSticky(window)
    }

    /// The Space a follow onto a shown Desktop lands in: its filing,
    /// or where a shown screen other than its Space's re-homes it.
    private func shownFollowSpace(
        of window: WindowID,
        on target: DesktopTarget
    ) -> SpaceID? {
        guard let filed = state.rememberedSpace(of: window) else {
            return nil
        }
        guard let screen = display(forUUID: target.displayIdentifier),
            let home = state.workspaces.display(of: filed),
            home != screen
        else { return filed }
        return moveHereSpace(on: screen)
    }
}
