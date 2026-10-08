import Foundation

/// A close the #1157 removal distrust delayed, and the same-app
/// window on another Space that macOS keyed meanwhile (#2002).
struct DelayedCloseDebt {
    let closing: WindowID
    let successor: WindowID
    /// The closing window's Space — the one the close-return owes.
    let space: SpaceID
    let noted: Date
    /// When the distrust episode opened — the instant the removal
    /// is re-filed at, and the start of "the user acted since".
    let episodeOpened: Date
    /// When it was noted, on the commanded-focus clock (#1088).
    let mark: ContinuousClock.Instant
    /// Our own focus follow carried the active Space to the
    /// successor — the one switch the debt survives.
    var followed = false
}

/// The removal facts the close-return tail acts on, and the
/// Space it owes a return to — nil for every removal the debt
/// does not cover.
struct CloseReturnFacts {
    let effects: AppliedEffects
    let owedSpace: SpaceID?
}

/// The delayed-close return (#2002): the debt's one home — the
/// fourth member of the #951/#958/#1532 one-machine family. It
/// changes FACTS only; the Space switch and the raise are the
/// close-return tail's. The let-outs and who may switch are
/// state-and-layout.md's; `DelayedCloseReturnTests` the verdicts,
/// `DelayedCloseSeamTests` the writer and call sites.
extension KiwiCore {
    /// How long a noted debt may wait for its confirmation: one
    /// more `transientRetrackDelay` than the follow-ups an
    /// episode may spend (`EventLoop.removalRecheckCap`).
    var delayedCloseBound: TimeInterval {
        let delay = timings.transientRetrackDelay.components
        let seconds =
            Double(delay.seconds) + Double(delay.attoseconds) / 1e18
        return Double(EventLoop.removalRecheckCap + 1) * seconds
    }

    /// Notes or voids the debt at an honored focus report.
    func noteDelayedClose(
        _ id: WindowID,
        after effects: AppliedEffects,
        selfEcho: Bool
    ) {
        // The successor's own duplicate, the follow's echo, or any
        // echo of our own raise (a landing float's) — none of them
        // the user moving on.
        if selfEcho || delayedCloseDebt?.successor == id { return }
        retireDelayedClose(touching: nil, why: "focus moved")
        let now = wallClock()
        guard let before = effects.focusBefore, before != id,
            let opened = eventLoop.delayedCloseOpened(before),
            let closing = state.windows[before],
            state.windows[id]?.pid == closing.pid,
            let space = state.workspaces.space(of: before),
            let home = state.workspaces.space(of: id), home != space,
            !recentClickReached(id, now: now)
        else { return }
        delayedCloseDebt = DelayedCloseDebt(
            closing: before,
            successor: id,
            space: space,
            noted: now,
            episodeOpened: opened,
            mark: .now
        )
        onLog(
            "close distrust: w\(id.raw) keyed while w\(before.raw) "
                + "is refused — space \(space.raw) owed its "
                + "close-return if the close confirms (#2002)"
        )
    }

    /// Marks the debt's successor as carried by our own follow.
    func noteDelayedCloseFollowed(_ id: WindowID) {
        guard delayedCloseDebt?.successor == id else { return }
        delayedCloseDebt?.followed = true
    }

    /// Drops the debt when its episode ends without a close or
    /// either window is re-keyed; `nil` drops it unconditionally.
    func retireDelayedClose(touching ids: Set<WindowID>?, why: String) {
        guard let debt = delayedCloseDebt else { return }
        if let ids, !ids.contains(debt.closing),
            !ids.contains(debt.successor)
        {
            return
        }
        delayedCloseDebt = nil
        onLog(
            "close distrust: w\(debt.closing.raw) debt retired — "
                + "\(why) (#2002)"
        )
    }

    /// The facts the close-return tail reads for this removal:
    /// unchanged, or — where the debt is owed — re-filed as the
    /// focus loss it was, with the Space the return is owed in.
    func healDelayedClose(
        _ event: KiwiEvent,
        reason: WindowGoneReason?,
        effects: AppliedEffects
    ) -> CloseReturnFacts {
        let unchanged = CloseReturnFacts(effects: effects, owedSpace: nil)
        guard let debt = delayedCloseDebt,
            let id = event.goneWindowID,
            id == debt.closing || id == debt.successor
        else { return unchanged }
        delayedCloseDebt = nil
        guard id == debt.closing, reason == .closed,
            let removed = effects.removedWindow, !removed.focusLost,
            removed.space == debt.space
        else { return unchanged }
        if let why = delayedCloseStandDown(debt) {
            onLog(
                "close distrust: w\(id.raw) confirmed late — "
                    + "return stood down (\(why)) (#2002)"
            )
            return unchanged
        }
        onLog(
            "close distrust: w\(id.raw) confirmed late — return owed "
                + "in space \(debt.space.raw) over "
                + "w\(debt.successor.raw) (#2002)"
        )
        var healed = effects
        healed.removedWindow = removed.losingFocus
        return CloseReturnFacts(effects: healed, owedSpace: debt.space)
    }

    /// Why the owed return stands down, nil where it runs.
    private func delayedCloseStandDown(
        _ debt: DelayedCloseDebt
    ) -> String? {
        let now = wallClock()
        guard now.timeIntervalSince(debt.noted) < delayedCloseBound
        else { return "expired" }
        guard debt.followed else { return "no follow of the successor" }
        // A Space's focus is one of its members, so the second
        // clause also places the successor in the active Space.
        guard state.workspaces.activeSpace != debt.space,
            activeSpace?.focused == debt.successor
        else { return "focus moved on" }
        // The fold's re-pick never focuses a fullscreen window
        // (#670), and the tail's belt still refuses one.
        guard state.workspaces[debt.space]?.focused != nil
        else { return "no raisable fallback" }
        // From the OPENING: a Dock or Window-menu pick that keyed
        // the successor lands before its report; the close click
        // itself lands before the episode.
        if leftPress(since: debt.episodeOpened) { return "a press" }
        if eventLoop.focusCommanded(since: debt.mark) {
            return "a commanded focus"
        }
        return nil
    }
}

extension AppliedEffects.RemovedWindow {
    /// The re-filing as a focus loss — `healDelayedClose`'s alone.
    fileprivate var losingFocus: Self {
        Self(
            app: app,
            bundleID: bundleID,
            pid: pid,
            isTransientOverlay: isTransientOverlay,
            space: space,
            focusLost: true,
            tiledSlot: tiledSlot
        )
    }
}
