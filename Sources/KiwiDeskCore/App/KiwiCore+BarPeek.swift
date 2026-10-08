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
        peek.content = { [weak self] source, space in
            self?.barPeekContent(source, on: space)
        }
        peek.pick = { [weak self] id, space in
            self?.pickBarRow(id, on: space)
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
            focus: barFocus(on: space)
        )
    }

    /// The window holding the system focus as a bar list reads it
    /// (#2063): a playing Monocle flip's owed target, else
    /// `lastFocused`, and only for the active Space — the one that
    /// carries it (#1214). `space` is a Space Bar chip's; an App
    /// Bar list has none, and a group never spans Spaces.
    func barFocus(on space: SpaceID?) -> WindowID? {
        guard space == nil || space == activeSpace?.id else { return nil }
        return pendingMonocleFocus?.to ?? state.workspaces.lastFocused
    }

    /// The window a click on a multi-window glyph focuses (#2063):
    /// the one after `barFocus` in its peek's order, wrapping, or
    /// the first where the focus is none of them — derived from
    /// focus, so no cycle position is stored. A window the focus
    /// door refuses (#1345) is stepped over, or the walk would stall
    /// on it; where it refuses every one, the first, whose refusal
    /// takes the glyph's plain switch.
    func glyphCycleTarget(_ pick: SpaceBarGlyphPick) -> WindowID? {
        let order =
            barPeekContent(pick.peekSource, on: pick.space)?.order ?? []
        guard let first = order.first else { return nil }
        let start =
            barFocus(on: pick.space).flatMap(order.firstIndex(of:))
            .map { $0 + 1 } ?? 0
        let walk = (0..<order.count).map {
            order[(start + $0) % order.count]
        }
        return walk.first { !raiseCrossesDesktops($0) } ?? first
    }
}

extension BarPeekSource {
    /// The menu "N more" opens: one app's titles under its header,
    /// or `+n`'s mixed rows.
    var menuKind: SpaceBarGlyphPick.Kind {
        if case .overflow = self { return .overflow }
        return .glyph
    }
}
