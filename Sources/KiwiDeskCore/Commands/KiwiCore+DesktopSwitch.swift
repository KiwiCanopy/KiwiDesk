import Foundation

/// The switch dispatch shared by `focus_desktop` and
/// `move_to_desktop_and_follow` (#26/#25) — split from
/// `KiwiCore+DesktopCommands` at the §2.1 ceiling when the
/// #1023 transition discipline joined it.
extension KiwiCore {
    /// What a switch dispatch did, so a caller can tell the
    /// three apart. `focus_desktop` only needs the response; a
    /// follow needs to know whether a reveal is coming, because
    /// that is what owes the moved window a focus (#1007) — and
    /// `.switched` is also exactly the case that folds the
    /// eager departure (#1023): the two are one question.
    enum DesktopSwitchOutcome {
        case alreadyShown
        case switched
        case refused(CommandResponse)

        var response: CommandResponse {
            switch self {
            case .alreadyShown, .switched: .ok()
            case .refused(let response): response
            }
        }
    }

    /// The one copy of the switch dispatch, for both verbs that
    /// switch. Stamps the switch at INTENT time — but only once
    /// the bridge has accepted it, so a refusal does not
    /// suppress a second of focus-follow that no switch earned.
    ///
    /// **Set, then hide the origin (#1023).** The pointer write
    /// alone half-performs the switch: macOS composites the
    /// target's windows but keeps compositing the origin's, so
    /// both Desktops render at once, the moved window "overlays"
    /// the old Desktop, and only a genuine gesture or click
    /// completes the swap — while every signal KiwiDesk trusts
    /// reports success. Hiding the origin is the missing half;
    /// set-then-hide measured as a complete switch on device
    /// (2026-08-26, argument on `WMBridge.hideSpaces`). The hide
    /// dispatches only after an ACCEPTED set — an unhidden
    /// origin under a refused set is today's behavior, an
    /// origin hidden under one is a blank screen.
    ///
    /// The hide's own Bool is deliberately unread: performed is
    /// not applied either way (os-private-apis.md), and the one
    /// honest check this surface allows is the deferred pointer
    /// re-query below — which verifies the SET landed, and only
    /// that; no pointer read can see the visual swap (#1023's
    /// first measurement). The transition's real confirmation
    /// stays the OS's own switch notification, exactly as a
    /// swipe's.
    func switchDesktop(
        to target: DesktopTarget,
        verb: String
    ) -> DesktopSwitchOutcome {
        guard !target.isCurrent else { return .alreadyShown }
        guard
            WMBridge.setCurrentSpace(
                target.space,
                displayIdentifier: target.displayIdentifier
            )
        else {
            onLog("\(verb): the Desktop bridge refused the switch")
            return .refused(
                .fail("the Desktop bridge refused the switch")
            )
        }
        // origin == space would mean isCurrent, which the guard
        // above already stood down on.
        if let origin = target.originSpace {
            _ = WMBridge.hideSpaces([origin])
        }
        lastDesktopSwitch = Date()
        // Behind the accepted set, like the stamp above: the
        // carry's in-flight promise for the windows THIS switch
        // will move (#1213) — a refused set moves nothing.
        stampStickyReachInFlight(
            forSwitchOn: target.displayIdentifier,
            in: target.spaces
        )
        scheduleDesktopSwitchVerify(target, verb: verb)
        return .switched
    }

    /// 600 ms: a wide margin over the ~120 ms a dispatched set
    /// needs before every pointer read answers the new space
    /// (device-measured 2026-08-26) — late enough that a landed
    /// switch can never read as dropped, early enough that the
    /// log still sits beside the command in a capture.
    private func scheduleDesktopSwitchVerify(
        _ target: DesktopTarget,
        verb: String
    ) {
        deferred.schedule(
            .desktopSwitchVerify,
            after: .milliseconds(600)
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning else { return }
            self.verifyDesktopSwitch(to: target, verb: verb)
        }
    }

    /// The deferred body, split out so the check is provable
    /// synchronously: the resolver and space overrides are
    /// process-global, and a test may not hold them across a
    /// suspension (`DesktopSwitchGuardTests`' arrangement note).
    func verifyDesktopSwitch(
        to target: DesktopTarget,
        verb: String
    ) {
        guard
            let current = NativeSpaces.currentSpace(
                displayUUID: target.displayIdentifier
            ),
            current != target.space
        else { return }
        onLog(
            "\(verb): the switch did not land — the display "
                + "still shows space \(current), not "
                + "\(target.space)"
        )
    }

    /// The eager departure fold of a follow onto a HIDDEN
    /// Desktop — #1023's second half, device-traced 2026-08-26:
    /// the moved window has physically left for a Desktop
    /// nobody shows yet, but nothing removes it from its origin
    /// space until some reconcile happens to notice, and the
    /// switch's own retile still holds it as an origin member,
    /// re-places it on the origin screen — and macOS re-assigns
    /// its Desktop to match the frame, undoing the move.
    /// Whether the removal or that retile wins the race decided
    /// each attempt; folding the departure NOW decides it. The
    /// fold files `.departed`, which is exactly what the #1010
    /// arrival rule needs to re-home the window when the
    /// reveal's reconcile lists it again — the same path a
    /// swipe-away takes. Runs only after an ACCEPTED switch, so
    /// the removal classifies as `vanished` against the stamp
    /// the switch just wrote; a refused switch folds nothing,
    /// because the window is then still where the user sees it.
    func departEagerly(_ window: WindowID) {
        let pid = state.windows[window]?.pid
        // The latch is the close-return stand-down's third arm
        // (#936: the ONE predicate governs the raise and the
        // restore arm alike) — held for exactly this synchronous
        // span, see its doc on `EventLoop`.
        eventLoop.eagerDepartureInFlight = window
        handle(.windowDestroyed(window, wasMinimized: false))
        eventLoop.eagerDepartureInFlight = nil
        // The state fold alone is a half-state: the event loop's
        // element registry would keep the window "already known"
        // to every later reconcile and to the heal's census
        // diff, so nothing would ever re-adopt it (device-traced
        // 2026-08-26 — the "ignored until minimized" report).
        if let pid {
            eventLoop.releaseWindowRegistration(window, pid: pid)
        }
        // And the reveal reap: the switch's own reconcile fires
        // on the pointer-move notification, ~100 ms after the
        // set — often BEFORE the moved window composites on the
        // destination — so it can miss the window, after which
        // the adoption heal quiets the id as a permanent
        // mismatch and nothing ever adopts it (#1023, owner
        // trace 2026-08-26: "ignored until I minimize and
        // respawn"). A direct per-pid reconcile past the reveal
        // is not gated by that quieting. 700 ms: past the
        // measured ~130–300 ms composite and past the 600 ms
        // desktop settle, so the retile that follows places the
        // adopted window instead of racing the settle's. That
        // settle's own arrival sweep (#1037) usually adopts it
        // first; this reap stays for a window that composites
        // after that sweep's census, and for a switch accepted
        // but never notified — no notification, no settle.
        guard let pid else { return }
        deferred.schedule(
            .desktopFollowReap,
            after: .milliseconds(700)
        ) { [weak self] in
            guard let self, self.eventLoop.isRunning else { return }
            self.eventLoop.reconcile(pid: pid, app: AppRef(pid: pid))
            self.retile(animated: true)
        }
    }
}
