import CoreGraphics

/// How the Shortcuts side lays its sections out (#3570 ▸ Ruling 5,
/// as the owner and the ui-designer amended it on 2026-11-23). The
/// column count is set when the side opens: one column while a
/// single one fits the sheet's room, else as many as the room holds
/// at a 400 pt pitch, at most three. Typing never changes it; the
/// filtered rows are rebalanced across the same columns. The fill is
/// column-major and may break at any row, the next column repeating
/// the section's title, at the breaks that make the columns most
/// even. VoiceOver reads down each column, then on to the next, and
/// ↑ ↓ scroll the one shared scroll view. Pure: heights are
/// estimated from the parts, never measured.
struct ShortcutsColumnPlan: Equatable {
    /// One section's estimated parts.
    struct Section: Equatable {
        /// The title, and the caption under it if any.
        var header: CGFloat
        var rows: Int
        /// A row's height and the stack's spacing above it; the
        /// sheet hands its own (`ShortcutsSheetView.planned`).
        var pitch: CGFloat = 28
        /// The repeated title over a section continued from the
        /// column before.
        var continued: CGFloat = 18

        var height: CGFloat { header + CGFloat(rows) * pitch }
    }

    /// One column's share of a section: its rows, and whether it
    /// continues the section from the column before.
    struct Piece: Equatable {
        let section: Int
        let rows: Range<Int>
        var continued: Bool { rows.lowerBound > 0 }
    }

    /// Each column's pieces, in reading order; empty for no sheet.
    let columns: [[Piece]]

    /// The pitch a column takes, its gap included.
    static let columnPitch: CGFloat = 400
    static let maxColumns = 3
    /// The room above every section but a column's first.
    static let sectionGap: CGFloat = 16

    /// No sheet drawn.
    static let empty = ShortcutsColumnPlan(columns: [])

    init(columns: [[Piece]]) {
        self.columns = columns
    }

    /// `sections` cut into `count` columns (#3570 ▸ Ruling 5b).
    init(sections: [Section], columns count: Int) {
        columns = Self.balanced(sections, into: max(count, 1)).columns
    }

    /// The width a side of `count` columns asks for: a pitch per
    /// column, `gap` of it between each two and none after the last,
    /// and `inset` on each side; 0 for one column, which takes the
    /// field row's width.
    static func width(columns count: Int, inset: CGFloat, gap: CGFloat)
        -> CGFloat
    {
        guard count > 1 else { return 0 }
        return CGFloat(count) * columnPitch - gap + 2 * inset
    }

    /// How many columns fit `room` points less `inset` each side.
    static func columnsFitting(
        _ room: CGFloat,
        inset: CGFloat,
        gap: CGFloat
    ) -> Int {
        let fit = Int((room - 2 * inset + gap) / columnPitch)
        return min(max(fit, 1), maxColumns)
    }

    /// The column count the side opens with, under a sheet `cap`
    /// tall: one while `single` — the sections as one column draws
    /// them — fits, else `limit`, the most the room holds. `closing`
    /// is the full-width section's height below the columns, 0 for
    /// none.
    static func count(
        single: [Section],
        closing: CGFloat,
        cap: CGFloat,
        limit: Int
    ) -> Int {
        let room = cap - (closing > 0 ? closing + sectionGap : 0)
        return height(single.map(\.height)) > room ? max(limit, 1) : 1
    }

    /// A column of whole sections, one gap between each two.
    static func height(_ heights: [CGFloat]) -> CGFloat {
        heights.reduce(0, +)
            + CGFloat(max(heights.count - 1, 0)) * sectionGap
    }
}
