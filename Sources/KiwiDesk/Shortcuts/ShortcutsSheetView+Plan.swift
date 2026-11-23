import SwiftUI

/// The sheet's sections as KiwiHub's column plan reads them
/// (#3570 ▸ Ruling 5): estimated from their parts, never measured.
extension ShortcutsSheetView {
    /// The caption font's line height and its mean advance per
    /// character, measured on macOS 27 (`ShortcutsSheetEstimateTests`).
    static let titleLine: CGFloat = 16
    static let captionLine: CGFloat = 12
    static let captionAdvance: CGFloat = 5.5

    /// A section's estimated parts, for KiwiHub's column plan: the
    /// title, a caption wrapped at `width`, and its rows.
    static func planned(
        _ section: Section,
        needle: String,
        width: CGFloat
    ) -> ShortcutsColumnPlan.Section {
        var header = titleLine + titleGap
        if let caption = section.caption, needle.isEmpty {
            let lines = (CGFloat(caption.count) * captionAdvance / width)
                .rounded(.up)
            header += partSpacing + lines * captionLine + captionGap
        }
        return ShortcutsColumnPlan.Section(
            header: header,
            rows: section.rows.count,
            pitch: partSpacing + rowHeight,
            continued: titleLine + titleGap
        )
    }

    /// `columns`, where it cuts exactly `flowing`'s rows; else one
    /// column of them whole, as a plan made for another sheet would
    /// draw nothing true.
    static func cut(
        _ columns: [[ShortcutsColumnPlan.Piece]],
        over flowing: [Section]
    ) -> [[ShortcutsColumnPlan.Piece]] {
        let whole = flowing.enumerated().map {
            ShortcutsColumnPlan.Piece(section: $0, rows: 0..<$1.rows.count)
        }
        func rows(_ pieces: some Sequence<ShortcutsColumnPlan.Piece>)
            -> [[Int]]
        {
            pieces.flatMap { piece in piece.rows.map { [piece.section, $0] } }
        }
        let exact = rows(columns.joined()) == rows(whole)
        return !columns.isEmpty && exact ? columns : [whole]
    }

    /// `columns` for one section: its chord slot and divider kept
    /// only where a row of it has a chord.
    static func columns(
        _ columns: ShortcutColumns?,
        keeping rows: [ShortcutRow]
    ) -> ShortcutColumns? {
        guard var columns, !rows.contains(where: { !$0.combo.isEmpty })
        else { return columns }
        columns.chords = false
        columns.chord = 0
        return columns
    }

    /// A run of rows' chord column, sized to its own widest
    /// (#3424); nil leaves the column the run sits in.
    static func chordColumns(_ rows: [ShortcutRow]?) -> SheetChordColumns {
        SheetChordColumns(rows: rows)
    }
}

/// `ShortcutPanelColumns` over `rows`, or nothing where the sheet
/// sizes them as one (#3424, #3570).
struct SheetChordColumns: ViewModifier {
    let rows: [ShortcutRow]?

    func body(content: Content) -> some View {
        if let rows {
            content.modifier(
                ShortcutPanelColumns(
                    badges: rows.contains { !$0.gestures.isEmpty },
                    chords: rows.contains { !$0.combo.isEmpty }
                )
            )
        } else {
            content
        }
    }
}
