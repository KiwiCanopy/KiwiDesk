import CoreGraphics

/// How the Shortcuts side lays its sections out (#3570 ▸ Ruling 5,
/// as the ui-designer amended it on 2026-11-23). The column count is
/// set when the side opens: one column while a single one fits the
/// sheet's room, else the fewest columns that do, as many as the room
/// holds at a 460 pt pitch and at most three. Typing never changes
/// it; the filtered rows are rebalanced across the same columns. The
/// fill is column-major and breaks only before a section title, at
/// the breaks that make the tallest column shortest. A section taller
/// than 1.25 × the even share may break at a row, and the next
/// column repeats its title. VoiceOver reads down each column, then
/// on to the next, and ↑ ↓ scroll the one shared scroll view. Pure:
/// heights are estimated from the parts, never measured.
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

    /// The pitch a column takes, its gap included: room for a row
    /// with two chords to keep its whole label.
    static let columnPitch: CGFloat = 460
    static let maxColumns = 3
    /// The room above every section but a column's first.
    static let sectionGap: CGFloat = 16
    /// How much taller than the even share a section may stand
    /// before it breaks at a row.
    static let breakShare: CGFloat = 1.25

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
    /// them — fits, else the fewest of the `split` columns up to
    /// `limit` whose tallest fits, else `limit`. `closing` is the
    /// full-width section's height below the columns, 0 for none.
    static func count(
        single: [Section],
        split: [Section],
        closing: CGFloat,
        cap: CGFloat,
        limit: Int
    ) -> Int {
        let room = cap - (closing > 0 ? closing + sectionGap : 0)
        let whole = height(single.map(\.height))
        guard whole > room, limit >= 2, !split.isEmpty else { return 1 }
        for count in 2...limit
        where balanced(split, into: count).tallest <= room {
            return count
        }
        return limit
    }

    /// A column of whole sections, one gap between each two.
    static func height(_ heights: [CGFloat]) -> CGFloat {
        heights.reduce(0, +)
            + CGFloat(max(heights.count - 1, 0)) * sectionGap
    }
}
