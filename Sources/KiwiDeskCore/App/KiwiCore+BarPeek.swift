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
        peek.content = { [weak self] in self?.barPeekContent($0) }
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
    /// menu lists them, every one a row; nil where none is left.
    func barPeekContent(_ source: BarPeekSource) -> BarPeekContent? {
        let rows = barWindowRows(source.windows)
        guard !rows.isEmpty else { return nil }
        return BarPeekContent(rows: rows)
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
