import CoreGraphics

extension TilingEngine {
    /// One window's turn in `retile`'s layout loop: skip a frame
    /// the window already holds or was already sent, else issue
    /// it and record the ask. The layout loop is its one caller,
    /// since only the layout loop records asks (#1694,
    /// `LayoutAskSeamTests`).
    func issueLayoutFrame(
        _ id: WindowID,
        target: CGRect,
        state: StateCoordinator,
        pass: RetilePass,
        animated: Bool,
        isNew: Bool,
        sizing promised: BatchSizing
    ) {
        guard let current = state.windows[id]?.frame
        else { return }
        // #677: the settled, echo-quiet state frame is the
        // app's answer to the engine's last ask — the gate
        // and its argument live on `observeAppAnswer`. Its
        // verdict doubles as the baseline trust for the ask
        // recorded below.
        let settledNow = observeAppAnswer(
            for: id,
            current: current
        )
        // #1439: a due corroboration probe stands in for
        // an ask the anchor already answers and is meant
        // to be issued, so neither skip below applies. A
        // forced pass keeps its own ask (#1055).
        let probe =
            pass.probes
            ? nil
            : takeCorroborationProbe(
                id,
                current: current,
                target: target
            )
        // Tolerance: apps clamp what we set (character
        // grids, minimum sizes), so the reported frame is
        // often a hair off the target. Re-applying an
        // unchanged target just wobbles the window. #677:
        // a target the app has twice refused is "already
        // there" too — re-issuing it restarts an
        // animation the window can never perform, forever.
        // An unanswered instant set outranks the stale state
        // frame: no re-ask, no slide from the corner (#1912).
        let sent = commandedFrame(of: id)
        // A window already at its park — lifted as macOS lifts a
        // parked window — is there, on a re-issuing pass too: only
        // a departure the stash owes forces a park. The stash's
        // rule: an unanswered ask that left the corner outranks
        // the state frame, here and in the tolerance skip below
        // (#1508, #1912, #2235).
        let parks = looksStashed(target)
        let leftThePark =
            parks && sent.map { !Self.parked($0, at: target) } == true
        if probe == nil, parks, !leftThePark,
            Self.parked(current, at: target)
        {
            animation.cancel(window: id)
            meter.add(\.framesSkipped)
            return
        }
        if probe == nil, !pass.reissues, let sent,
            animation.targetFrame(window: id) == nil,
            Self.close(sent, to: target)
        {
            meter.add(\.framesSkipped)
            return
        }
        if probe == nil, !pass.reissues, !leftThePark,
            Self.close(current, to: target)
                || sizeBoundExplains(
                    id,
                    current: current,
                    target: target
                )
        {
            animation.cancel(window: id)
            meter.add(\.framesSkipped)
            return
        }
        meter.add(\.framesIssued)
        let issued = probe?.frame ?? target
        let from = sent ?? current
        let instant = applyFrame(
            id,
            from: from,
            to: issued,
            animated: animated
                && !Self.parkSnaps(from: from, to: issued) {
                    looksStashed($0)
                },
            isNewWindow: isNew,
            sizing: promised
        )
        boundLearner.recordAsk(
            id,
            size: issued.size,
            settledFrom: settledNow
                ? current.size : probe?.baseline
        )
        if Self.instantAskOwesProbe(
            pass: pass,
            switching: motionGate.isSwitching,
            wroteInstantly: instant
        ) {
            onInstantLayoutAsk(id)
        }
    }

    /// Whether a layout frame parks or unparks a window — a corner
    /// at either end — which snaps on an animated pass too: a park
    /// is a hide, never a corner flight (#881; #2235 ruling,
    /// 2026-10-22).
    static func parkSnaps(
        from: CGRect,
        to: CGRect,
        _ looksStashed: (CGRect) -> Bool
    ) -> Bool {
        looksStashed(from) || looksStashed(to)
    }

    /// Whether a layout ask owes the #677 settle probe itself: an
    /// instant write never settles, so no animation schedules it
    /// (#2187). `wroteInstantly` is `applyFrame`'s own verdict. A
    /// re-issuing pass or a watched switch's owes none — a switch
    /// would read every window it shows.
    static func instantAskOwesProbe(
        pass: RetilePass,
        switching: Bool,
        wroteInstantly: Bool
    ) -> Bool {
        wroteInstantly && !pass.reissues && !switching
    }
}
