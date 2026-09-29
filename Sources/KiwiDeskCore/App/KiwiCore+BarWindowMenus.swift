import AppKit

/// The window rows of an app glyph's and an App Bar item's menu
/// (#1518, the owner's rulings of 2026-09-28 and 2026-09-29 in its
/// body). A row acting on ONE window names it — for a glyph or a
/// group standing for several, through a submenu of their titles —
/// and acts through the public verbs, never a menu-only path.
extension KiwiCore {
    /// `movable`: the Space Bar's rows only. The App Bar lists the
    /// Space its screen shows, so a move to the focused Space never
    /// applies there and the row is left out rather than greyed.
    func windowRows(
        _ windows: [WindowID],
        movable: Bool
    ) -> [BarMenuRow] {
        let live = windows.filter { state.windows[$0] != nil }
        guard let app = live.first.flatMap({ state.windows[$0] })
        else { return [] }
        var rows: [BarMenuRow] = []
        if movable { rows.append(moveRow(live)) }
        rows.append(floatRow(live))
        rows += [.separator, quitRow(app)]
        return rows
    }

    /// "Current Space" is the Space holding the system focus —
    /// `state.workspaces.activeSpace` — never `currentSpace(on:)`
    /// of the chip's screen; greyed where the window already is,
    /// and where the move's own sticky gate would refuse it.
    private func moveRow(_ windows: [WindowID]) -> BarMenuRow {
        let title = L("bar.menu.move_here", "Move to Current Space")
        let target = state.workspaces.activeSpace
        let homes = Dictionary(
            uniqueKeysWithValues: windows.map {
                ($0, state.workspaces.space(of: $0))
            }
        )
        let movable = { (id: WindowID) in
            guard let target, homes[id] != target else { return false }
            return self.stickyMoveBlock(id, to: target) == nil
        }
        let move = { [weak self] (id: WindowID) in
            guard let target else { return }
            _ = self?.execute(
                "move_to_space",
                args: [.string(target.raw), .number(Double(id.raw))]
            )
        }
        guard windows.count > 1 else {
            let id = windows[0]
            return .action(title, enabled: movable(id)) { move(id) }
        }
        let rows = windows.map { id in
            BarMenuRow.action(windowTitle(id), enabled: movable(id)) {
                move(id)
            }
        }
        return .submenu(title, enabled: rows.contains { $0.enabled }, rows)
    }

    /// The label follows the window's own float setting, the one
    /// `toggle_floating` flips; a group's submenu ticks each window
    /// that floats.
    private func floatRow(_ windows: [WindowID]) -> BarMenuRow {
        guard windows.count > 1 else {
            let id = windows[0]
            let floats = state.windows[id]?.isFloating == true
            return .action(
                floats
                    ? L("bar.menu.tile_window", "Tile Window")
                    : L("bar.menu.float_window", "Float Window")
            ) { [weak self] in
                _ = self?.execute(
                    floats ? "make_tiled" : "make_floating",
                    args: [.number(Double(id.raw))]
                )
            }
        }
        let rows = windows.map { id in
            BarMenuRow.action(
                windowTitle(id),
                checked: state.windows[id]?.isFloating == true
            ) { [weak self] in
                _ = self?.execute(
                    "toggle_floating",
                    args: [.number(Double(id.raw))]
                )
            }
        }
        return .submenu(
            L("bar.menu.float_window", "Float Window"),
            rows
        )
    }

    /// Greyed for Finder, which macOS relaunches, and for KiwiDesk
    /// itself, whose Quit is the status item's.
    private func quitRow(_ app: ManagedWindow) -> BarMenuRow {
        let quits =
            !EventLoop.isOwnProcess(app.pid)
            && app.appBundleID != Self.finderBundleID
        return .action(
            L("bar.menu.quit_app", "Quit %1$@", app.appName),
            enabled: quits
        ) { [weak self] in
            self?.shelves.contextMenus.terminateApp(app.pid)
        }
    }

    /// A window's row in a submenu: its title, else its app's name.
    private func windowTitle(_ id: WindowID) -> String {
        guard let window = state.windows[id] else { return "" }
        return window.title.isEmpty ? window.appName : window.title
    }

}
