import Foundation

/// Jump to window's two actions (#1875): Jump focuses a row's
/// window wherever it is, and Bring here moves it into the Space
/// the user is on first. Both reuse the doors the bars and Open
/// or Focus already take, never a path of their own.
extension KiwiCore {
    /// Focuses `target`: a window on another Space switches the way
    /// a Space Bar pick does, one on an away Desktop is reached
    /// over the bridge, a minimized one is restored, and a hidden
    /// app is brought forward.
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

    /// Moves `target` into the active Space and focuses it.
    /// Returns false, cued, where it cannot move; a hidden app or
    /// a minimized window, which has no window here to move yet,
    /// is jumped to instead.
    @discardableResult
    public func bringHere(_ target: JumpEntry.Target) -> Bool {
        withUserMotion {
            guard case .window(let id) = target,
                let active = state.workspaces.activeSpace
            else {
                jump(to: target)
                return true
            }
            if let window = state.windows[id] {
                return bringTracked(window, into: active)
            }
            if let away = state.awayWindows[id] {
                return bringAway(away, into: active)
            }
            jumpToWindow(id)
            return true
        }
    }

    private func jumpToWindow(_ id: WindowID) {
        if let window = state.windows[id] {
            // A full-screen window keeps its own macOS Space, which
            // no KiwiDesk Space switch reaches (#670).
            guard !window.isFullscreen else {
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
            reachJumpTarget(away)
            return
        }
        if let parked = state.minimizeOrder.first(where: { $0.id == id }) {
            openOrFocus.deminiaturize(parked.pid, id)
            openOrFocus.activate(parked.pid)
        }
    }

    private func reachJumpTarget(_ away: AwayWindow) {
        guard let bundleID = away.appBundleID?.lowercased(),
            let reach = awayReach(bundleID: bundleID),
            let entry = reach.windows.first(where: {
                $0.window.id == away.id
            })
        else { return }
        reachAwayWindow(
            entry.window,
            desktop: entry.desktop,
            snapshot: reach.snapshot,
            verb: "jump_to_window"
        )
    }

    private func bringTracked(
        _ window: ManagedWindow,
        into active: SpaceID
    ) -> Bool {
        guard !window.isFullscreen else {
            cueWindowAction(
                .cannotBringHere(window: jumpName(window)),
                on: window.id
            )
            return false
        }
        if state.workspaces.space(of: window.id) != active {
            let moved = execute(
                "move_to_space",
                args: [.string(active.raw), .number(Double(window.id.raw))]
            )
            guard moved.isSuccess else { return false }
        }
        pickBarRow(window.id, on: nil)
        return true
    }

    /// Hops the window onto the Desktop its screen shows, filed
    /// into `active`, and owes it the focus at its arrival.
    private func bringAway(
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
                .cannotBringHere(
                    window: away.title.isEmpty ? away.appName : away.title
                ),
                on: away.id
            )
            return false
        }
        followFocus.record(away.id)
        return true
    }

    private func jumpName(_ window: ManagedWindow) -> String {
        window.title.isEmpty ? window.appName : window.title
    }
}
