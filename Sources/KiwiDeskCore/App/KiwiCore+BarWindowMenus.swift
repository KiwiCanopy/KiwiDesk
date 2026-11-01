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
        // The app's name heads its rows on every surface (#2024).
        var rows: [BarMenuRow] = [.header(app.appName), newWindowRow(app)]
        if movable { rows.append(moveRow(live)) }
        // A pocket window's float slot is Remove from Pocket (#2612
        // ▸ 4); a group keeps a submenu per kind.
        let pocketed = live.filter { state.pocketPhase(of: $0) != nil }
        let plain = live.filter { !pocketed.contains($0) }
        let grouped = live.count > 1
        if !plain.isEmpty { rows.append(floatRow(plain, grouped: grouped)) }
        if !pocketed.isEmpty {
            rows.append(removeFromPocketRow(pocketed, grouped: grouped))
        }
        rows.append(pocketRow(live))
        rows.append(appRulesRow(app))
        rows += [.separator, closeRow(live), quitRow(app)]
        return rows
    }

    /// The app's File ▸ New Window, pressed through AX. Offered
    /// from state alone (bars.md), so an app with no such row
    /// refuses at perform time with a cue rather than greying;
    /// greyed for KiwiDesk itself, as Quit is.
    private func newWindowRow(_ app: ManagedWindow) -> BarMenuRow {
        .action(
            L("bar.menu.new_window", "New Window"),
            enabled: !EventLoop.isOwnProcess(app.pid)
        ) { [weak self] in
            _ = self?.execute(
                "new_window",
                args: [.number(Double(app.id.raw))]
            )
        }
    }

    /// The window's close button, through AX; a window without
    /// one refuses at perform time, as New Window does.
    private func closeRow(_ windows: [WindowID]) -> BarMenuRow {
        let title = L("bar.menu.close_window", "Close Window")
        let closes = { (id: WindowID) in
            self.state.windows[id].map {
                !EventLoop.isOwnProcess($0.pid)
            } ?? false
        }
        let close = { [weak self] (id: WindowID) in
            _ = self?.execute(
                "close_window",
                args: [.number(Double(id.raw))]
            )
        }
        guard windows.count > 1 else {
            let id = windows[0]
            return .action(title, enabled: closes(id)) { close(id) }
        }
        let rows = windows.map { id in
            BarMenuRow.action(windowRowName(id), enabled: closes(id)) {
                close(id)
            }
        }
        return .submenu(title, enabled: rows.contains { $0.enabled }, rows)
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
            BarMenuRow.action(windowRowName(id), enabled: movable(id)) {
                move(id)
            }
        }
        return .submenu(title, enabled: rows.contains { $0.enabled }, rows)
    }

    /// The label follows the window's own float setting, the one
    /// `toggle_floating` flips; a group's submenu ticks each window
    /// that floats. A Tile that detection would refuse is greyed,
    /// its reason the subtitle — the pill's own sentence (#1810).
    private func floatRow(
        _ windows: [WindowID],
        grouped: Bool
    ) -> BarMenuRow {
        guard grouped else {
            let id = windows[0]
            let floats = state.windows[id]?.isFloating == true
            let refusal = floats ? tileRefusal(of: id) : nil
            return .action(
                floats
                    ? L("bar.menu.tile_window", "Tile Window")
                    : L("bar.menu.float_window", "Float Window"),
                enabled: refusal == nil,
                subtitle: refusal?.sentence
            ) { [weak self] in
                _ = self?.execute(
                    floats ? "make_tiled" : "make_floating",
                    args: [.number(Double(id.raw))]
                )
            }
        }
        let rows = windows.map { id in
            let floats = state.windows[id]?.isFloating == true
            let refusal = floats ? tileRefusal(of: id) : nil
            return BarMenuRow.action(
                windowRowName(id),
                enabled: refusal == nil,
                checked: floats,
                subtitle: refusal?.sentence
            ) { [weak self] in
                _ = self?.execute(
                    "toggle_floating",
                    args: [.number(Double(id.raw))]
                )
            }
        }
        return .submenu(
            L("bar.menu.float_window", "Float Window"),
            enabled: rows.contains { $0.enabled },
            rows
        )
    }

    /// The float row's slot while a window is the pocket's (#2612
    /// ▸ 4): unmarks it through `toggle_pocket_window` naming it, as
    /// ⌃⌥⇧P does. Greyed for a window its app's Pocket key keeps,
    /// the subtitle saying where that key lives.
    private func removeFromPocketRow(
        _ windows: [WindowID],
        grouped: Bool
    ) -> BarMenuRow {
        let title = L("bar.menu.remove_from_pocket", "Remove from Pocket")
        let row = { [weak self] (id: WindowID, title: String) in
            let keyed = self?.state.pocketKeyOwner(of: id) != nil
            return BarMenuRow.action(
                title,
                enabled: !keyed,
                subtitle: keyed ? Self.pocketKeyKeepsIt : nil
            ) { [weak self] in
                _ = self?.execute(
                    "toggle_pocket_window",
                    args: [.number(Double(id.raw))]
                )
            }
        }
        guard grouped else { return row(windows[0], title) }
        let rows = windows.map { row($0, windowRowName($0)) }
        return .submenu(title, enabled: rows.contains { $0.enabled }, rows)
    }

    static var pocketKeyKeepsIt: String {
        L(
            "bar.menu.pocket_keyed",
            "Its Pocket key keeps it — %1$@ ▸ %2$@ ▸ %3$@",
            L("home.title", "Settings"),
            L("destination.shortcuts", "Shortcuts & Gestures"),
            L("shortcuts.section.pocket", "Pocket")
        )
    }

    /// Puts the window in the pocket through `pocket` naming it
    /// (#2678), greyed where the pocket would refuse it — taken
    /// under One window, a window no pocket takes, or one its
    /// app's Pocket key keeps (#2612 ▸ 11).
    private func pocketRow(_ windows: [WindowID]) -> BarMenuRow {
        let title = L("bar.menu.pocket_window", "Pocket Window")
        let takes = { (id: WindowID) in
            self.pocketNamedRefusal(id) == nil
        }
        let pocket = { [weak self] (id: WindowID) in
            _ = self?.execute("pocket", args: [.number(Double(id.raw))])
        }
        guard windows.count > 1 else {
            let id = windows[0]
            return .action(title, enabled: takes(id)) { pocket(id) }
        }
        let rows = windows.map { id in
            BarMenuRow.action(windowRowName(id), enabled: takes(id)) {
                pocket(id)
            }
        }
        return .submenu(title, enabled: rows.contains { $0.enabled }, rows)
    }

    /// Greyed for an app with no bundle id, which no rule can
    /// match.
    private func appRulesRow(_ app: ManagedWindow) -> BarMenuRow {
        let bundle = app.appBundleID
        return .action(
            L("bar.menu.app_rules", "App Rules…"),
            enabled: bundle != nil
        ) { [weak self] in
            guard let bundle else { return }
            self?.barMenuHooks.openSettings(.appRule(bundle))
        }
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

    /// A window's row in a submenu: the glyph menu's own name for
    /// it (#1947), since the app is the menu's context.
    func windowRowName(_ id: WindowID) -> String {
        guard let window = state.windows[id] else { return "" }
        return SpaceBarWindowMenu.windowName(window.title)
    }

    /// A window named outside its app's menu — a refusal pill — by
    /// its title, else its app's name.
    func windowTitle(_ id: WindowID) -> String {
        guard let window = state.windows[id] else { return "" }
        return window.title.isEmpty ? window.appName : window.title
    }

}
