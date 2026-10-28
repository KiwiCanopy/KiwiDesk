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
        shelves.shelfBeyondBars = { [weak self] window in
            self?.overflowMarks.shelf(drawnIn: window)
        }
        peek.content = { [weak self] source, space in
            self?.barPeekContent(source, on: space)
        }
        peek.pick = { [weak self] id, space in
            self?.fromSpaceBar { self?.pickBarRow(id, on: space) }
        }
        peek.openMenu = { [weak self] source, space, anchor in
            self?.presentBarWindowMenu(
                source.windows,
                kind: source.menuKind,
                space: space,
                at: anchor
            )
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
        guard !rows.isEmpty else { return nil }
        return BarPeekContent(
            rows: rows,
            checks: source.isList,
            focus: barFocus(on: space),
            header: source.header
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
