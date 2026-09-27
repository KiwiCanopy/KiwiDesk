import AppKit

/// What a click on a Space Bar glyph or `+n` does (#1528, the
/// owner rulings in its body): a one-window glyph switches to its
/// Space and focuses that window; a glyph standing for several
/// windows, and `+n`, open a menu of them and switch nothing until
/// a row is picked. A click elsewhere on the chip stays
/// `focusSpace`.
extension KiwiCore {
    func wireSpaceBarGlyphs() {
        spaceBars.glyphActions.pick = { [weak self] in
            self?.pickFromSpaceBar($0)
        }
        spaceBars.glyphActions.tooltip = { [weak self] in
            self?.spaceBarTooltip($0)
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
        let menu = SpaceBarWindowMenu.make(rows) { [weak self] id in
            self?.focusFromSpaceBar(id, on: space)
        }
        spaceBars.glyphActions.present(menu, pick.anchor)
    }

    /// Switches to `space` landing on `window`, or focuses it where
    /// `space` is already active. The landing focus is seeded where
    /// the window is a member — a traveler's home, not the Space it
    /// renders on — so the switch's own handoff raises it, once.
    func focusFromSpaceBar(_ window: WindowID, on space: SpaceID) {
        guard state.windows[window] != nil else { return }
        guard space != activeSpace?.id else {
            focusWithMonocleFlip(window, step: nil)
            return
        }
        if let home = state.workspaces.space(of: window) {
            state.workspaces.focus(window, in: home)
        }
        _ = focusSpace([.string(space.raw)])
    }

    func spaceBarMenuRows(
        _ windows: [WindowID]
    ) -> [SpaceBarWindowMenu.Row] {
        windows.compactMap { id in
            guard let window = state.windows[id] else { return nil }
            return SpaceBarWindowMenu.Row(
                window: id,
                app: window.appName,
                title: window.title,
                icon: NSRunningApplication(
                    processIdentifier: window.pid
                )?.icon
            )
        }
    }

    /// The app on the first line, then one line per window title
    /// (#1514's ruling); read at hover, so it is never stale.
    func spaceBarTooltip(_ windows: [WindowID]) -> String? {
        let members = windows.compactMap { state.windows[$0] }
        guard let first = members.first else { return nil }
        let titles = members.map(\.title).filter { !$0.isEmpty }
        return ([first.appName] + titles).joined(separator: "\n")
    }
}
