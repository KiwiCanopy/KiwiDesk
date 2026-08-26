import Foundation

/// The switch dispatch shared by `focus_desktop` and
/// `move_to_desktop_and_follow` (#26/#25) — split from
/// `KiwiCore+DesktopCommands` at the §2.1 ceiling when the
/// #1023 transition discipline joined it.
extension KiwiCore {
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
        // origin == space would mean isCurrent, which the guard
        // above already stood down on.
        if let origin = target.originSpace {
            _ = WMBridge.hideSpaces([origin])
        }
        lastDesktopSwitch = Date()
        scheduleDesktopSwitchVerify(target, verb: verb)
        return .ok()
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
}
