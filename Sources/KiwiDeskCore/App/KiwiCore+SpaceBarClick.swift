import AppKit

/// What a click on a Space Bar glyph or `+n` does (#1528, the
/// owner rulings in its body, #1946's and #2063's): a glyph
/// switches to its Space and focuses a window — its one window,
/// or for several the next in its peek's order (`glyphCycleTarget`)
/// with the peek shown on it; `+n` toggles its peek and switches
/// nothing until a row is picked — VoiceOver's press opening the
/// native menu instead. A click elsewhere on the chip stays
/// `focusSpace`.
extension KiwiCore {
    func wireSpaceBarGlyphs() {
        spaceBars.glyphActions.pick = { [weak self] pick in
            self?.withUserMotion { self?.pickFromSpaceBar(pick) }
        }
        spaceBars.glyphActions.accessibilityPress = { [weak self] pick in
            self?.pressSpaceBarGlyph(pick)
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
        guard pick.peekSource.isList else {
            shelves.peek.dismiss()
            focusFromSpaceBar(pick.windows[0], on: pick.space)
            return
        }
        // No menu: the list is the peek, its rows the picks; `+n`
        // mixes apps, so it has no next window and toggles.
        guard pick.kind == .glyph, let next = glyphCycleTarget(pick)
        else {
            spaceBars.glyphActions.togglePeek(pick)
            return
        }
        // Focus first, so the peek's check reads the window landed.
        focusFromSpaceBar(next, on: pick.space)
        spaceBars.glyphActions.showPeek(pick)
    }

    /// VoiceOver's press on a glyph: a list's native menu at the
    /// target, the peek's accessible twin; a one-window glyph picks.
    func pressSpaceBarGlyph(_ pick: SpaceBarGlyphPick) {
        guard pick.peekSource.isList else {
            spaceBars.glyphActions.pick(pick)
            return
        }
        presentBarWindowMenu(
            pick.windows,
            kind: pick.kind,
            space: pick.space,
            at: pick.anchor
        )
    }

    /// The full menu of `windows` at `anchor` — VoiceOver's press
    /// and the peek's "N more" (#1946) — its rows the one bar-row
    /// pick a peek row takes.
    func presentBarWindowMenu(
        _ windows: [WindowID],
        kind: SpaceBarGlyphPick.Kind,
        space: SpaceID?,
        at anchor: NSView
    ) {
        let rows = spaceBarMenuRows(windows, focus: barFocus(on: space))
        guard !rows.isEmpty else { return }
        let menu = SpaceBarWindowMenu.make(rows, kind: kind) {
            [weak self] id in
            self?.pickBarRow(id, on: space)
        }
        spaceBars.glyphActions.present(menu, anchor)
    }

    /// The one pick a bar list's row takes — a peek row's and a
    /// window menu row's alike (#1946): the click on that window's
    /// own bar item. `space` is the chip's, and the row does what
    /// its glyph does; an App Bar row has none and does what its
    /// App Bar item does, on the Space that bar draws it in.
    func pickBarRow(_ window: WindowID, on space: SpaceID?) {
        withUserMotion {
            guard let space else {
                selectFromAppBar(window)
                return
            }
            focusFromSpaceBar(window, on: space)
        }
    }

    /// A click on an App Bar item, or its peek row: focuses the
    /// window where the bar draws it — a traveler included, which
    /// its home Space would switch away from.
    func selectFromAppBar(_ window: WindowID) {
        focusWithMonocleFlip(window, step: nil)
    }

    /// Switches to `space` landing on `window` through the one
    /// follow-shaped switch, or focuses it where `space` is already
    /// active. A menu row picked after its window left `space` —
    /// the menu is modal, the loop keeps running — is dropped; a
    /// window the raise gate refuses (#1345) takes the chip's plain
    /// switch instead, so the Space still hands focus over — the
    /// one policy a glyph, a peek row and a menu row share.
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
        _ windows: [WindowID],
        focus: WindowID? = nil
    ) -> [SpaceBarWindowMenu.Row] {
        barWindowRows(windows).map { row in
            SpaceBarWindowMenu.Row(
                row: row,
                // The focus door's own refusal (#1345): a row it
                // would refuse is greyed, never hidden (#802).
                enabled: !raiseCrossesDesktops(row.window),
                focused: row.window == focus
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
