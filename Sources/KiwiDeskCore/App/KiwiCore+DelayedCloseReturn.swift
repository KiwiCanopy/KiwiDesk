import Foundation

/// A close the #1157 removal distrust delayed, and the same-app
/// window on another Space that macOS keyed meanwhile (#2002).
struct DelayedCloseDebt {
    let closing: WindowID
    let successor: WindowID
    /// The closing window's Space — the one the close-return owes.
    let space: SpaceID
    let noted: Date
    /// When it was noted, on the commanded-focus clock (#1088).
    let mark: ContinuousClock.Instant
    /// Our own focus follow carried the active Space to the
    /// successor — the one switch the debt survives.
    var followed = false
}

/// The delayed-close return (#2002, owner ruling 2026-10-06): a
/// close the distrust refused is confirmed only after macOS has
/// keyed the app's window on another Space and our focus follow
/// has switched there, so the removal no longer loses the focus
/// and the #936 raise never runs. The heal re-files the removal
/// as if it had landed when the episode opened and hands it to
/// the ONE close-return tail, which raises the closed window's
/// Space fallback. Every let-out leaves today's behavior:
/// - no open distrust episode on the window the report left —
///   an undelayed close, or the #1930 order;
/// - a successor on the closed window's own Space;
/// - a report that was our own raise's echo or carried click
///   provenance, or any later honored report for a third window;
/// - a left press or a commanded focus after the note, or a
///   Space switch that was not our follow of the successor —
///   the user acting during the episode;
/// - a confirmation past `delayedCloseBound`.
/// `DelayedCloseReturnTests` pins the heal and each let-out.
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

    /// Notes or voids the debt at an HONORED focus report: called
    /// once, from `handleWindowFocused`'s honored path.
    func noteDelayedClose(
        _ id: WindowID,
        after effects: AppliedEffects,
        selfEcho: Bool
    ) {
        // The successor's own duplicate, or the follow's echo.
        if delayedCloseDebt?.successor == id { return }
        delayedCloseDebt = nil
        let now = wallClock()
        guard !selfEcho,
            let before = effects.focusBefore, before != id,
            eventLoop.removalDistrusted[before] != nil,
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
            mark: .now
        )
        onLog(
            "close distrust: w\(id.raw) keyed while w\(before.raw) "
                + "is refused — space \(space.raw) owed its "
                + "close-return if the close confirms (#2002)"
        )
    }

    /// Marks the debt's successor as carried by our own follow —
    /// called from `landFocusFollow` alone.
    func noteDelayedCloseFollowed(_ id: WindowID) {
        guard delayedCloseDebt?.successor == id else { return }
        delayedCloseDebt?.followed = true
    }

    /// The removal facts the close-return tail reads: `effects`
    /// unchanged, or — where the debt is owed — switched back to
    /// the closed window's Space and re-filed as a focus loss.
    func healDelayedClose(
        _ event: KiwiEvent,
        reason: WindowGoneReason?,
        effects: AppliedEffects
    ) -> AppliedEffects {
        guard let debt = delayedCloseDebt,
            let id = event.goneWindowID,
            id == debt.closing || id == debt.successor
        else { return effects }
        delayedCloseDebt = nil
        guard id == debt.closing, reason == .closed,
            let removed = effects.removedWindow, !removed.focusLost,
            removed.space == debt.space
        else { return effects }
        if let why = delayedCloseStandDown(debt) {
            onLog(
                "close distrust: w\(id.raw) confirmed late — "
                    + "return stood down (\(why)) (#2002)"
            )
            return effects
        }
        onLog(
            "close distrust: w\(id.raw) confirmed late — returning "
                + "to space \(debt.space.raw) over "
                + "w\(debt.successor.raw) (#2002)"
        )
        applyFocusedSpaceSwitch(to: debt.space)
        var healed = effects
        healed.removedWindow = removed.losingFocus
        return healed
    }

    /// Why the owed return stands down, nil where it runs.
    private func delayedCloseStandDown(
        _ debt: DelayedCloseDebt
    ) -> String? {
        let now = wallClock()
        guard now.timeIntervalSince(debt.noted) < delayedCloseBound
        else { return "expired" }
        guard debt.followed else { return "no follow of the successor" }
        let active = state.workspaces.activeSpace
        guard active != debt.space,
            state.workspaces.space(of: debt.successor) == active,
            activeSpace?.focused == debt.successor
        else { return "focus moved on" }
        if let press = lastLeftClick?.at, press >= debt.noted {
            return "a press"
        }
        if eventLoop.focusCommanded(since: debt.mark) {
            return "a commanded focus"
        }
        return nil
    }
}
