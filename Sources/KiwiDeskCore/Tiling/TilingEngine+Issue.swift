import CoreGraphics

/// One window's turn in `retile`, split from `TilingEngine.swift`
/// at the §2.1 ceiling (#1944): skip a frame the window already
/// holds or was already sent, else issue it and record the ask.
extension TilingEngine {
    func issue(
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
        if probe == nil, !pass.reissues, let sent,
            animation.targetFrame(window: id) == nil,
            Self.close(sent, to: target)
        {
            meter.add(\.framesSkipped)
            return
        }
        if probe == nil, !pass.reissues,
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
        applyFrame(
            id,
            from: sent ?? current,
            to: issued,
            animated: animated,
            isNewWindow: isNew,
            sizing: promised
        )
        boundLearner.recordAsk(
            id,
            size: issued.size,
            settledFrom: settledNow
                ? current.size : probe?.baseline
        )
    }
}
