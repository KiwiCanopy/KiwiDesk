import AppKit

/// The bars' hover peek (#1946): its content is built from the
/// bar lists' state-only rows when it shows, never stored on a
/// view, so a renamed window needs no refresh — and never from the
/// menu's rows, whose enablement reads the compositor (#1925). A
/// row picks through the one `pickBarRow` the window menu's rows
/// take.
extension KiwiCore {
    func wireBarPeek() {
        let peek = shelves.peek
        spaceBars.glyphActions.peek = peek
        appBars.itemActions.peek = peek
        // An overflow mark's panel wears the shelf it draws in.
        // So does the pocket plate's (#2678).
        shelves.shelfBeyondBars = { [weak self] window in
            self?.overflowMarks.shelf(drawnIn: window)
                ?? self?.pocketPlate.shelf(drawnIn: window)
        }
        peek.content = { [weak self] source, space in
            self?.barPeekContent(source, on: space)
        }
        peek.pick = { [weak self] id, space in
            self?.fromSpaceBar { self?.pickBarRow(id, on: space) }
        }
        peek.land = { [weak self] landing in
            self?.barMenuHooks.openSettings(landing)
        }
        peek.openMenu = { [weak self] source, space, anchor in
            self?.presentBarWindowMenu(source, space: space, at: anchor)
        }
    }

    /// What a hovered item's peek shows: its windows as the glyph
    /// menu lists them, every one a row, a list's checking the
    /// window `barFocus(on: space)` names (#2063); nil where none
    /// is left.
    func barPeekContent(
        _ source: BarPeekSource,
        on space: SpaceID?
    ) -> BarPeekContent? {
        let rows = barWindowRows(source.windows)
        guard !rows.isEmpty else {
            // An empty Pocket explains itself (#2941).
            return source.keysPocketWindows
                ? BarPeekContent(empty: pocketEmptyState()) : nil
        }
        let focus = barFocus(on: space)
        guard source.keysPocketWindows else {
            return BarPeekContent(
                rows: rows,
                checks: source.isList,
                focus: focus,
                header: source.header
            )
        }
        // The pocket lists an app's own window apart, with its key
        // (#2923); the GUI renders the chord (#2612 ▸ 1).
        let owners = pocketRowOwners(rows.map(\.window))
        return BarPeekContent(
            rows: rows.filter { owners[$0.window] == nil },
            checks: source.isList,
            focus: focus,
            header: source.header,
            keyed: rows.filter { owners[$0.window] != nil },
            chord: { [barMenuHooks] id in
                owners[id].flatMap { barMenuHooks.pocketKeyChord($0)?.drawn }
            }
        )
    }

    /// Each of `windows` an app's own Pocket key keeps, by that
    /// app's bundle id: the one split the pocket's peek and its
    /// VoiceOver menu read (#2923).
    func pocketRowOwners(_ windows: [WindowID]) -> [WindowID: String] {
        Dictionary(
            uniqueKeysWithValues: windows.compactMap { id in
                state.pocketKeyOwner(of: id).map { (id, $0) }
            }
        )
    }

    /// The window holding the system focus as a bar list reads it
    /// (#2063): `lastFocused`, and only for the active Space —
    /// the one that carries it (#1214). `space` is a Space Bar chip's; an App
    /// Bar list has none, and a group never spans Spaces.
    func barFocus(on space: SpaceID?) -> WindowID? {
        guard space == nil || space == activeSpace?.id else { return nil }
        return state.workspaces.lastFocused
    }
}

extension BarPeekSource {
    /// The menu "N more" opens: one app's titles under its header,
    /// or the mixed rows of `+n` and a collapsed Space.
    var menuKind: SpaceBarGlyphPick.Kind {
        switch self {
        case .overflow, .space, .run, .pocket: .overflow
        case .glyph, .appItem: .glyph
        }
    }
}
