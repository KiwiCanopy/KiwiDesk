import Foundation

/// Jump to window's two actions (#1875): Jump focuses a row's
/// window wherever it is, and Move here moves it into the Space
/// the user is on first. Whatever is picked takes the focus. Both
/// reuse the doors the bars and Open or Focus already take.
extension KiwiCore {
    /// Focuses `target`: a window on another Space switches the way
    /// a bar row's pick does, one on an away Desktop is reached
    /// over the bridge, a minimized one is restored and followed,
    /// and a hidden app is brought forward.
    public func jump(to target: JumpEntry.Target) {
        withUserMotion {
            switch target {
            case .hiddenApp(let pid):
                openOrFocus.activate(pid)
            case .window(let id):
                jumpToWindow(id)
            }
        }
    }

    /// Moves `target` into the active Space and focuses it at its
    /// arrival. Returns false, cued, where it cannot move; a hidden
    /// app, which has no window to move yet, is jumped to.
    @discardableResult
    public func moveHere(_ target: JumpEntry.Target) -> Bool {
        withUserMotion {
            guard case .window(let id) = target,
                let active = state.workspaces.activeSpace
            else {
                jump(to: target)
                return true
            }
            if let window = state.windows[id] {
                return moveTracked(window, into: active)
            }
            if let away = state.awayWindows[id] {
                return moveAway(away, into: active)
            }
            if let parked = minimized(id) {
                // Filed here at its arrival, wherever it lands.
                jump.owe(id, in: active, at: wallClock(), relocates: true)
                openOrFocus.deminiaturize(parked.pid, id)
                openOrFocus.activate(parked.pid)
            }
            return true
        }
    }

    private func jumpToWindow(_ id: WindowID) {
        if let window = state.windows[id] {
            // A full-screen window keeps its own macOS Space, which
            // no KiwiDesk Space switch reaches (#670); its app comes
            // forward instead — the accepted v1 residue.
            guard !window.isFullscreen else {
                onLog("jump: w\(id.raw) is full screen — app activated")
                openOrFocus.activate(window.pid)
                return
            }
            // The bar lists' one pick (#1946): a Space Bar row on
            // another Space, an App Bar row where it is drawn — a
            // sticky window renders here, whatever its home.
            let space = state.workspaces.space(of: id)
            let elsewhere =
                space != state.workspaces.activeSpace && !window.isSticky
            pickBarRow(id, on: elsewhere ? space : nil)
            return
        }
        if let away = state.awayWindows[id] {
            guard reachJumpTarget(away) else {
                onLog(
                    "jump: w\(id.raw) not reached on its Desktop — "
                        + "app activated"
                )
                openOrFocus.activate(away.pid)
                return
            }
            return
        }
        if let parked = minimized(id) {
            // An un-minimize is an open: the launch follow carries
            // the user to the Space it lands in (#1599).
            if let unminimized = parked.bundleID {
                oweLaunchFollow(unminimized)
            }
            // Where no rule carries it away it lands here, and is
            // focused; where the follow switches, this stands down.
            if let active = state.workspaces.activeSpace {
                jump.owe(id, in: active, at: wallClock(), relocates: false)
            }
            openOrFocus.deminiaturize(parked.pid, id)
            openOrFocus.activate(parked.pid)
        }
    }

    private func minimized(
        _ id: WindowID
    ) -> StateCoordinator.MinimizedWindow? {
        state.minimizeOrder.first { $0.id == id }
    }

    /// False where the bridge, the census or the switch refused.
    private func reachJumpTarget(_ away: AwayWindow) -> Bool {
        guard let bundleID = away.appBundleID?.lowercased(),
            let reach = awayReach(bundleID: bundleID),
            let entry = reach.windows.first(where: {
                $0.window.id == away.id
            })
        else { return false }
        return reachAwayWindow(
            entry.window,
            desktop: entry.desktop,
            snapshot: reach.snapshot,
            verb: "jump_to_window"
        )
    }

    private func moveTracked(
        _ window: ManagedWindow,
        into active: SpaceID
    ) -> Bool {
        let name = window.title.isEmpty ? window.appName : window.title
        guard !window.isFullscreen else {
            cueWindowAction(.cannotMoveHere(window: name), on: window.id)
            return false
        }
        // A ∞ window already renders here, so it is only focused;
        // any other block is the sticky gate's own refusal, cued.
        if let block = stickyMoveBlock(window.id, to: active) {
            guard block == .global, window.stickyScope == .global else {
                return !stickyMoveRefused(window.id, to: active)
            }
            pickBarRow(window.id, on: nil)
            return true
        }
        if state.workspaces.space(of: window.id) != active {
            let moved = execute(
                "move_to_space",
                args: [.string(active.raw), .number(Double(window.id.raw))]
            )
            // `move_to_space` answers `.ok` where the sticky gate
            // stood the move down, so the membership is the verdict
            // — a construction net: the gate asked above reads the
            // same display for the placed active Space, so no
            // fixture reaches it (guard-prover, 2026-10-12).
            guard moved.isSuccess,
                state.workspaces.space(of: window.id) == active
            else {
                cueWindowAction(.cannotMoveHere(window: name), on: window.id)
                return false
            }
        }
        pickBarRow(window.id, on: nil)
        return true
    }

    /// Hops the window onto the Desktop its screen shows, filed
    /// into `active`, and owes it the focus at its arrival.
    private func moveAway(
        _ away: AwayWindow,
        into active: SpaceID
    ) -> Bool {
        guard let bundleID = away.appBundleID?.lowercased(),
            let hopped = hopAwayWindows(
                bundleID: bundleID,
                into: active,
                only: away.id
            ),
            hopped.contains(away.id)
        else {
            cueWindowAction(
                .cannotMoveHere(
                    window: away.title.isEmpty ? away.appName : away.title
                ),
                on: away.id
            )
            return false
        }
        jump.owe(away.id, in: active, at: wallClock(), relocates: false)
        return true
    }
}
