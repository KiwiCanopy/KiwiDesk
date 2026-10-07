import AppKit

/// What a click on a Space Bar glyph or `+n` does (#1528, the
/// owner rulings in its body): a one-window glyph switches to its
/// Space and focuses that window; a glyph standing for several
/// windows, and `+n`, open a menu of them and switch nothing until
/// a row is picked. A click elsewhere on the chip stays
/// `focusSpace`.
extension KiwiCore {
    func wireSpaceBarGlyphs() {
        spaceBars.glyphActions.pick = { [weak self] pick in
            self?.withUserMotion { self?.pickFromSpaceBar(pick) }
        }
        // A strip held under the pointer re-centres as it leaves
        // (#1528 item 21), through the one bar refresh — deferred,
        // since a hold can end inside a render or a relayout.
        spaceBars.onStripReleased = { [weak self] in
            self?.deferred.schedule(.stripRecentre, after: .zero) {
                [weak self] in
                self?.updateBars()
            }
        }
    }

    func pickFromSpaceBar(_ pick: SpaceBarGlyphPick) {
        if pick.kind == .glyph, pick.windows.count == 1 {
            focusFromSpaceBar(pick.windows[0], on: pick.space)
            return
        }
        let rows = spaceBarMenuRows(pick.windows)
        guard !rows.isEmpty else { return }
        let space = pick.space
        let menu = SpaceBarWindowMenu.make(rows, kind: pick.kind) {
            [weak self] id in
            self?.focusFromSpaceBar(id, on: space)
        }
        spaceBars.glyphActions.present(menu, pick.anchor)
    }

    /// Switches to `space` landing on `window` through the one
    /// follow-shaped switch, or focuses it where `space` is already
    /// active. A menu row picked after its window left `space` —
    /// the menu is modal, the loop keeps running — is dropped; a
    /// window the raise gate refuses (#1345) takes the chip's plain
    /// switch instead, so the Space still hands focus over.
    func focusFromSpaceBar(_ window: WindowID, on space: SpaceID) {
        guard let members = state.workspaces[space],
            state.effectiveMembers(of: members).contains(window)
        else { return }
        guard space != activeSpace?.id else {
            focusWithMonocleFlip(window, step: nil)
            return
        }
        guard !raiseCrossesDesktops(window) else {
            _ = focusSpace([.string(space.raw)])
            return
        }
        followSwitch(to: space, focusing: window)
    }

    func spaceBarMenuRows(
        _ windows: [WindowID]
    ) -> [SpaceBarWindowMenu.Row] {
        barWindowRows(windows).map { row in
            SpaceBarWindowMenu.Row(
                row: row,
                // The focus door's own refusal (#1345): a row it
                // would refuse is greyed, never hidden (#802).
                enabled: !raiseCrossesDesktops(row.window)
            )
        }
    }

    /// `windows` as the bar lists name them, from state alone — no
    /// compositor read, so a hover may ask it (#1946).
    func barWindowRows(_ windows: [WindowID]) -> [BarWindowRow] {
        windows.compactMap { id in
            guard let window = state.windows[id] else { return nil }
            return BarWindowRow(
                window: id,
                pid: window.pid,
                app: window.appName,
                title: window.title,
                icon: BarIconCache.icon(pid: window.pid)
            )
        }
    }
}
