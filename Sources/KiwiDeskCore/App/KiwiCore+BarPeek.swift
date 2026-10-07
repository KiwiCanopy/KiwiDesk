import Foundation

/// The bars' hover peek (#1946): its content is built from the
/// bar lists' state-only rows when it shows, never stored on a
/// view, so a renamed window needs no refresh — and never from the
/// menu's rows, whose enablement reads the compositor (#1925).
extension KiwiCore {
    func wireBarPeek() {
        let peek = shelves.peek
        spaceBars.glyphActions.peek = peek
        appBars.itemActions.peek = peek
        peek.content = { [weak self] in self?.barPeekContent($0) }
    }

    /// What a hovered item's peek shows: its windows as the glyph
    /// menu lists them, every one a row; nil where none is left.
    func barPeekContent(_ source: BarPeekSource) -> BarPeekContent? {
        let rows = barWindowRows(source.windows)
        guard !rows.isEmpty else { return nil }
        return BarPeekContent(rows: rows)
    }
}
