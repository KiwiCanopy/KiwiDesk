import Foundation

/// The bars' hover peek (#1946): its content is built from the
/// glyph menu's one row source when it shows, never stored on a
/// view, so a renamed window needs no refresh.
extension KiwiCore {
    func wireBarPeek() {
        let peek = shelves.peek
        spaceBars.glyphActions.peek = peek
        appBars.itemActions.peek = peek
        peek.content = { [weak self] in self?.barPeekContent($0) }
        peek.shelf = { [weak self] in
            self?.tiler.settings.kiwishelf ?? KiwiShelf()
        }
    }

    /// What a hovered item's peek shows: its windows as the glyph
    /// menu lists them, every one a row; nil where none is left.
    func barPeekContent(_ source: BarPeekSource) -> BarPeekContent? {
        let rows = spaceBarMenuRows(source.windows)
        guard !rows.isEmpty else { return nil }
        return BarPeekContent(rows: rows, icons: source.showsIcons)
    }
}
