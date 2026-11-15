import Foundation

/// A titled Space rule's one late match (#3341): a new window whose
/// title matched no rule at its creation is filed by the first
/// title report that matches one, as a creation placement — no
/// follow, no focus, no event — and never after the user acted.
extension KiwiCore {
    /// Files `match`'s window in its rule's Space unless the user
    /// pressed since it arrived, `CrossSessionMatch.titleSettle`
    /// passed, or the window is where the user is or cannot move
    /// — the cross-session settle pass's checks, which no cue
    /// narrates. True when it filed.
    @discardableResult
    func payLateTitledRule(
        _ match: AppliedEffects.LateTitledRule
    ) -> Bool {
        let window = match.window
        // Its create may still land: the record waits for the settle.
        if arrivals.waiting[window] != nil {
            state.titledRulePending[window] = match.arrivedAt
            return false
        }
        let age = wallClock().timeIntervalSince(match.arrivedAt)
        let from = state.workspaces.space(of: window)
        guard age <= CrossSessionMatch.titleSettle,
            !launchFollow.pressed(within: age),
            state.workspaces[match.space] != nil,
            from != match.space,
            window != state.workspaces.lastFocused,
            spaceMoveBlock(window) == nil,
            stickyMoveBlock(window, to: match.space) == nil
        else {
            onLog(
                "titled rule: w\(window.raw) late match to "
                    + "\(match.space.raw) stood down"
            )
            return false
        }
        fileMembership(
            window,
            into: match.space,
            from: from,
            restoring: true
        )
        onLog("titled rule: w\(window.raw) filed in \(match.space.raw)")
        retile()
        return true
    }

    /// Pays the late match a title report found while the arrival's
    /// create was still due, from the window's title now.
    func payHeldTitledRule(_ id: WindowID) {
        guard let title = state.windows[id]?.title,
            let match = state.consumeTitledRule(id, title: title)
        else { return }
        payLateTitledRule(match)
    }
}
