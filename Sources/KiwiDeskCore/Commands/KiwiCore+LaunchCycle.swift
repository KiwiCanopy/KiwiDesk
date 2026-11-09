import Foundation

/// Repeat presses of Open or Focus cycle the app's windows
/// (#637), and `focus_app_window` walks the same ring either
/// way (#3131): when `focus_or_spawn` fires while one of the target
/// app's windows is already focused, the shortcut advances to
/// the app's next window — space order, then slot order,
/// wrapping — instead of re-activating an app that is already
/// forward (which did nothing visible).
///
/// Since #1146 the ring also holds the app's windows UP on
/// Desktops nobody shows, by the rank they will return in, and
/// cycling onto one REACHES it over the bridge
/// (`KiwiCore+LaunchReach`). Without the bridge the ring is the
/// tracked windows alone.
extension KiwiCore {
    /// One step through the focused app's ring
    /// (`focus_app_window`, #3131).
    func cycleFocusedAppWindow(
        direction: ModeCycleDirection,
        verb: String
    ) -> AppCycleStep {
        guard let current = state.workspaces.lastFocused,
            let window = state.windows[current]
        else { return .notFocused }
        guard let bundleID = window.appBundleID?.lowercased() else {
            return .noBundleID
        }
        return cycleAppWindow(
            bundleID: bundleID,
            direction: direction,
            verb: verb
        )
    }

    /// The one step through an app's ring, shared by
    /// `focus_or_spawn`'s repeat press (always `.next`) and
    /// `focus_app_window` (#3131). `bundleID` arrives
    /// lowercased; `verb` names the caller on the away reach's
    /// log line.
    func cycleAppWindow(
        bundleID: String,
        direction: ModeCycleDirection,
        verb: String
    ) -> AppCycleStep {
        guard let current = state.workspaces.lastFocused,
            let window = state.windows[current]
        else { return .notFocused }
        guard window.appBundleID?.lowercased() == bundleID else {
            return .otherAppFocused
        }
        // OS truth, not just our state: after a cmd-tab away,
        // the stale state focus must not turn a "bring it back"
        // press into a surprise cycle. A sibling process in
        // front is the same app (#1785).
        guard frontmostOwns(pid: window.pid) else {
            return .notFrontmost
        }
        let reach = canDriveDesktops ? awayReach(bundleID: bundleID) : nil
        let ring = cycleRing(
            bundleID: bundleID,
            away: Set(reach?.windows.map(\.window.id) ?? [])
        )
        guard let index = ring.firstIndex(of: current) else {
            return .outsideRing
        }
        guard ring.count > 1 else { return .loneWindow }
        let step = direction == .next ? 1 : ring.count - 1
        let landed = focusCycleTarget(
            ring[(index + step) % ring.count],
            reach: reach.map { (reach: $0, verb: verb) }
        )
        return landed ? .stepped : .reachRefused
    }

    /// The first press (#1840): focuses the app's most recently
    /// focused tracked window by command — a window in another
    /// Space is reached by a switch, not by the app's report,
    /// which the #1161 distrust may refuse. Tracked windows
    /// outrank away ones: an app with nothing here falls through
    /// to the reach. False — the press takes the old path — when
    /// the app tracks no window, or its target sits on a Desktop
    /// nobody shows, where `focusWindow` refuses the raise.
    func pullRecentWindow(bundleID: String, pid: pid_t) -> Bool {
        guard let target = pullTarget(bundleID: bundleID, pid: pid),
            !raiseCrossesDesktops(target)
        else { return false }
        return focusCycleTarget(target, reach: nil)
    }

    private func pullTarget(bundleID: String, pid: pid_t) -> WindowID? {
        mostRecentWindow(
            of: cycleRing(bundleID: bundleID, away: []),
            pid: pid
        )
    }

    /// The app's window a press means (#1840), shared with
    /// `move_here` (#1513): recency first; with none yet (a fresh
    /// KiwiDesk) the app's own focused window — asked only of a
    /// pid LaunchServices names — else the first of `candidates`,
    /// which come in ring order.
    func mostRecentWindow(
        of candidates: [WindowID],
        pid: pid_t?
    ) -> WindowID? {
        guard !candidates.isEmpty else { return nil }
        let recent = candidates.max {
            state.focusRecencyRank(of: $0)
                < state.focusRecencyRank(of: $1)
        }
        if let recent, state.focusRecencyRank(of: recent) > 0 {
            return recent
        }
        if let pid, pid > 0,
            let own = eventLoop.focusedWindowID(pid: pid),
            candidates.contains(own)
        {
            return own
        }
        return candidates.first
    }

    /// Every window of the app in cycle order: spaces in their
    /// canonical order, each space's row within — present
    /// members and the UP away ones in `away`, by rank.
    /// Deterministic, so repeat presses walk a stable ring.
    /// Transient overlays (a launcher's panel, #300) are not in
    /// it: they exist momentarily, never wear a ring, and are
    /// not "the app's windows" in the user's mental model.
    func cycleRing(
        bundleID: String,
        away: Set<WindowID>
    ) -> [WindowID] {
        state.workspaces.allSpaces.flatMap { space in
            withAwayMembers(space.windows, of: space.id).filter { id in
                if let window = state.windows[id] {
                    return window.appBundleID?.lowercased() == bundleID
                        && !window.isTransientOverlay
                }
                return away.contains(id)
            }
        }
    }

    /// Focuses the cycle's chosen window. A same-space target is a
    /// plain focus; one on another Space switches the
    /// way a follow move does (`followSwitch`). A STICKY
    /// target never switches (#414): its membership names only
    /// its hidden home space while the window renders right
    /// here — the same fly-back `scheduleFocusFollow` refuses.
    /// An AWAY target is reached (#1146), logged under the
    /// calling verb; a refused reach answers false.
    private func focusCycleTarget(
        _ id: WindowID,
        reach: (reach: AwayReach, verb: String)?
    ) -> Bool {
        if let (reach, verb) = reach,
            let entry = reach.windows.first(where: { $0.window.id == id })
        {
            return reachAwayWindow(
                entry.window,
                desktop: entry.desktop,
                snapshot: reach.snapshot,
                verb: verb
            )
        }
        guard
            let space = state.workspaces.space(of: id),
            space != state.workspaces.activeSpace,
            state.windows[id]?.isSticky != true
        else {
            focusWindow(id, warp: true)
            return true
        }
        followSwitch(to: space, focusing: id)
        return true
    }
}

/// What one step through an app's ring did (#3131).
/// `focus_or_spawn` reads anything but `.stepped` as "fall
/// through to the pull"; `focus_app_window` refuses with the
/// rule each case names.
enum AppCycleStep: Equatable {
    case stepped
    /// No window holds the focus.
    case notFocused
    /// The focus is another app's: only a caller naming its own
    /// app (`focus_or_spawn`) reaches it.
    case otherAppFocused
    /// The focused window's app reports no bundle identifier.
    case noBundleID
    /// The OS has another app in front (#1785).
    case notFrontmost
    /// The focused window is a transient overlay, which the
    /// ring leaves out (#300).
    case outsideRing
    /// The ring holds no other window.
    case loneWindow
    /// The next window is on a Desktop the bridge did not
    /// switch to (#1146).
    case reachRefused
}
